//
//  TraceLogger.m
//  FPSDisplay
//
//  Created by kangya on 11/10/2018.
//  Copyright © 2018 kangya. All rights reserved.
//

#import "TraceLogger.h"
#import <mach/mach.h>
#include <dlfcn.h>
#include <pthread.h>
#include <sys/types.h>
#include <limits.h>
#include <string.h>
#include <mach-o/dyld.h>
#include <mach-o/nlist.h>

#pragma mark DEFINE MACRO FOR DIFFERENT CPU ARCHITECTURE
//armv7｜armv7s｜arm64都是ARM处理器的指令集
//i386｜x86_64 是Mac处理器的指令集
//arm64：iPhone6s | iphone6s plus｜iPhone6｜ iPhone6 plus｜iPhone5S | iPad Air｜ iPad mini2(iPad mini with Retina Display)
//armv7s：iPhone5｜iPhone5C｜iPad4(iPad with Retina Display)
//armv7：iPhone4｜iPhone4S｜iPad｜iPad2｜iPad3(The New iPad)｜iPad mini｜iPod Touch 3G｜iPod Touch4
//i386是针对intel通用微处理器32位处理器
//x86_64是针对x86架构的64位处理器
//模拟器32位处理器测试需要i386架构，
//模拟器64位处理器测试需要x86_64架构，
//真机32位处理器需要armv7,或者armv7s架构，
//真机64位处理器需要arm64架构。

//_STRUCT_MCONTEXT64
//{
//    _STRUCT_ARM_EXCEPTION_STATE64    es;
//    _STRUCT_ARM_THREAD_STATE64    ss; // 线程数据
//    _STRUCT_ARM_NEON_STATE64    ns;
//};
//#define _STRUCT_ARM_THREAD_STATE64    struct __darwin_arm_thread_state64
//_STRUCT_ARM_THREAD_STATE64
//{
//    __uint64_t    __x[29];    /* General purpose registers x0-x28 */
//    __uint64_t    __fp;        /* Frame pointer x29 */
//    __uint64_t    __lr;        /* Link register x30 */
//    __uint64_t    __sp;        /* Stack pointer x31 */
//    __uint64_t    __pc;        /* Program counter */
//    __uint32_t    __cpsr;    /* Current program status register */
//    __uint32_t    __pad;    /* Same size for 32-bit or 64-bit clients */
//};

#if defined(__arm64__)
#define DETAG_INSTRUCTION_ADDRESS(A) ((A) & ~(3UL))
#define BS_THREAD_STATE_COUNT ARM_THREAD_STATE64_COUNT
#define BS_THREAD_STATE ARM_THREAD_STATE64
#define BS_FRAME_POINTER __fp
#define BS_STACK_POINTER __sp
#define BS_INSTRUCTION_ADDRESS __pc
#elif defined(__arm__)
#define DETAG_INSTRUCTION_ADDRESS(A) ((A) & ~(1UL))
#define BS_THREAD_STATE_COUNT ARM_THREAD_STATE_COUNT
#define BS_THREAD_STATE ARM_THREAD_STATE
#define BS_FRAME_POINTER __r[7]
#define BS_STACK_POINTER __sp
#define BS_INSTRUCTION_ADDRESS __pc

#elif defined(__x86_64__)
#define DETAG_INSTRUCTION_ADDRESS(A) (A)
#define BS_THREAD_STATE_COUNT x86_THREAD_STATE64_COUNT
#define BS_THREAD_STATE x86_THREAD_STATE64
#define BS_FRAME_POINTER __rbp
#define BS_STACK_POINTER __rsp
#define BS_INSTRUCTION_ADDRESS __rip

#elif defined(__i386__)
#define DETAG_INSTRUCTION_ADDRESS(A) (A)
#define BS_THREAD_STATE_COUNT x86_THREAD_STATE32_COUNT
#define BS_THREAD_STATE x86_THREAD_STATE32
#define BS_FRAME_POINTER __ebp
#define BS_STACK_POINTER __esp
#define BS_INSTRUCTION_ADDRESS __eip

#endif

#define CALL_INSTRUCTION_FROM_RETURN_ADDRESS(A) (DETAG_INSTRUCTION_ADDRESS((A)) - 1)

#if defined(__LP64__)
#define TRACE_FMT         "%-4d%-31s 0x%016lx %s + %lu"
#define POINTER_FMT       "0x%016lx"
#define POINTER_SHORT_FMT "0x%lx"
#define CZB_NLIST struct nlist_64
#else
#define TRACE_FMT         "%-4d%-31s 0x%08lx %s + %lu"
#define POINTER_FMT       "0x%08lx"
#define POINTER_SHORT_FMT "0x%lx"
#define CZB_NLIST struct nlist
#endif

typedef struct StackFrameEntry {
    const struct StackFrameEntry *const previous;
    const uintptr_t return_address;
} StackFrameEntry;

static mach_port_t main_thread_id;

@implementation TraceLogger

+(void)load {
    main_thread_id = mach_thread_self();
}

+(int)getThreadCount {
    char name[256];
    mach_msg_type_name_t count;
    thread_act_array_t list;
    task_threads(mach_task_self(), &list, &count);
    
//    NSLog(@"获取线程个数：%d", count);
    
    NSMutableArray *nameArray = [NSMutableArray array];
    for (int i = 0 ; i < count; i++) {
        
        pthread_t pt = pthread_from_mach_thread_np(list[i]);
        
        if (pt) {
            name[0] = '\0';
            pthread_getname_np(pt, name, sizeof name);
            if (!strcmp(name, [[NSThread currentThread] name].UTF8String)) {
            }
        }
        
        if (name[0] != '\0') {
            NSString *ocName = [[NSString alloc] initWithUTF8String:name];
            [nameArray addObject:ocName];
//            NSLog(@"thread is %s", name);
        }
    }
    [nameArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//        NSLog(@"thread name is %@", obj);
    }];
    return count;
}

#pragma mark interface
+(NSString *)czb_backtraceOfNSThread:(NSThread *)thread {
    return _czb_backtraceOfThread(czb_machThreadFromNSThread(thread));
}

+(NSString *)czb_backtraceOfAllThread:(NSThread *)thread {
    thread_act_array_t threads;
    mach_msg_type_number_t thread_count = 0;
    const task_t this_task = mach_task_self();
    
    kern_return_t kr = task_threads(this_task, &threads, &thread_count);
    if (kr != KERN_SUCCESS) {
        return @"Fail to get information of all threads";
    }
    
    NSMutableString *resultString = [[NSMutableString alloc]initWithFormat:@"Call Backtrace of %u threads", thread_count];
    
    for (int i = 0; i < thread_count; i++) {
        [resultString appendString:_czb_backtraceOfThread(threads[i])];
    }
    return [resultString copy];
}

#pragma mark HandleMachineContext
bool czb_fillThreadStateIntoMachineContext(thread_t thread, _STRUCT_MCONTEXT *machineContext) {
    mach_msg_type_name_t state_count = BS_THREAD_STATE_COUNT;
    kern_return_t kr = thread_get_state(thread, BS_THREAD_STATE, (thread_state_t)&machineContext->__ss,&state_count);
    
    return (kr == KERN_SUCCESS);
}
bool czb_mach_instructionAddress(mcontext_t const machineContext) {
    return machineContext->__ss.BS_INSTRUCTION_ADDRESS;
}

bool czb_mach_linkRegister(mcontext_t const machineContext) {
    #if defined(__i386__) || defined(__x86_64__)
      return 0;
    #else
      return machineContext->__ss.__lr;
    #endif
}

// get the function's Frame Pointer at the thread stack, store the last Stack Frame's Stack Pointer
uintptr_t czb_mach_framePointer(mcontext_t const machineContext) {
    return machineContext->__ss.BS_FRAME_POINTER;
}

// copy frame to dst
kern_return_t czb_mach_copyMem(const void *const src, void *const dst, const size_t numBytes) {
    vm_size_t bytesCopied = 0;
    return vm_read_overwrite(mach_task_self(), (vm_address_t)src, (vm_size_t)numBytes, (vm_address_t)dst, &bytesCopied);
}

#pragma mark Get call backtrace of a mach_thread
NSString *_czb_backtraceOfThread(thread_t thread) {
    uintptr_t backtraceBuffer[50];
    int i = 0;
    NSMutableString *resultString = [[NSMutableString alloc] initWithFormat:@"Backtrace of Thread %u:\n", thread];
    
    _STRUCT_MCONTEXT machineContext;
    if (!czb_fillThreadStateIntoMachineContext(thread, &machineContext)) {
        return [NSString stringWithFormat:@"Fail to get information about thread: %u", thread];
    }
    
    const uintptr_t instructionAddress = czb_mach_instructionAddress(&machineContext);
    backtraceBuffer[i] = instructionAddress;
    ++i;
    
    uintptr_t linkRegister = czb_mach_linkRegister(&machineContext);
    if (linkRegister) {
        backtraceBuffer[i] = linkRegister;
        i++;
    }
    
    if (instructionAddress == 0) {
        return @"Fail to get instruction address";
    }
    
    StackFrameEntry frame = {0};
    const uintptr_t framePtr = czb_mach_framePointer(&machineContext);
    if (framePtr == 0 || czb_mach_copyMem((void *)framePtr, &frame, sizeof(frame)) != KERN_SUCCESS) {
        return @"Fail to get frame pointer";
    }
    
    for (; i < 50; i++) {
        // stack pointer
        backtraceBuffer[i] = frame.return_address;
        if (backtraceBuffer[i] == 0 || frame.previous == 0 || czb_mach_copyMem(frame.previous, &frame, sizeof(frame)) != KERN_SUCCESS) {
            break;
        }
    }
    
    int backtraceLength = i;
    Dl_info symbolicated[backtraceLength];
    czb_symbolicate(backtraceBuffer, symbolicated, backtraceLength, 0);
    for (int i = 0; i < backtraceLength; i++) {
        [resultString appendFormat:@"%@", czb_logBacktraceEntry(i, backtraceBuffer[i], &symbolicated[i])];
    }
    [resultString appendFormat:@"\n"];
    return [resultString copy];
}

#pragma mark Symbolicate
void czb_symbolicate(const uintptr_t* const backtraceBuffer, Dl_info* const symbolsBuffer, const int numEntries, const int skippedEntries) {
    int i = 0;
    
    if (!skippedEntries && i < numEntries) {
        czb_dladdr(backtraceBuffer[i], &symbolsBuffer[i]);
        i++;
    }
    
    for (; i < numEntries; i++) {
        czb_dladdr(CALL_INSTRUCTION_FROM_RETURN_ADDRESS(backtraceBuffer[i]), &symbolsBuffer[i]);
    }
}

///*
// * Structure filled in by dladdr().
// */
//typedef struct dl_info {
//    const char      *dli_fname;     /* Pathname of shared object */
//    void            *dli_fbase;     /* Base address of shared object */
//    const char      *dli_sname;     /* Name of nearest symbol */
//    void            *dli_saddr;     /* Address of nearest symbol */
//} Dl_info;

bool czb_dladdr(const uintptr_t address, Dl_info* const info) {
    info->dli_fname = NULL;
    info->dli_fbase = NULL;
    info->dli_sname = NULL;
    info->dli_saddr = NULL;
    
    const uint32_t idx = czb_imageIndexContainingAddress(address);
    if (idx == UINT_MAX) {
        return false;
    }
    const struct mach_header* header = _dyld_get_image_header(idx);
    const uintptr_t imageVMAddrSlide = (uintptr_t)_dyld_get_image_vmaddr_slide(idx);
    const uintptr_t addressWithSlide = address - imageVMAddrSlide;
    //链接时程序的基址 = __LINKEDIT.VM_Address – __LINKEDIT.File_Offset + silde的改变值
    const uintptr_t segmentBase = czb_segmentBaseOfImageIndex(idx) + imageVMAddrSlide;
    if (segmentBase == 0) return false;
    
    info->dli_fname = _dyld_get_image_name(idx);
    info->dli_fbase = (void *)header;
    
    // Find symbol tables and get whichever symbol is closest to the adress
    const CZB_NLIST* bestMatch = NULL;
    uintptr_t bestDistance = ULONG_MAX;
    uintptr_t cmdPtr = czb_firstCmdAfterHeader(header);
    if (cmdPtr == 0) return false;
 
//    /*
//     * The symtab_command contains the offsets and sizes of the link-edit 4.3BSD
//     * "stab" style symbol table information as described in the header files
//     * <nlist.h> and <stab.h>.
//     */
//    struct symtab_command {
//        uint32_t    cmd;        /* LC_SYMTAB */
//        uint32_t    cmdsize;    /* sizeof(struct symtab_command) */
//        uint32_t    symoff;        /* symbol table offset */
//        uint32_t    nsyms;        /* number of symbol table entries */
//        uint32_t    stroff;        /* string table offset */
//        uint32_t    strsize;    /* string table size in bytes */
//    };
// symtab_command主要是提供符号表的偏移量，以及元素个数，还有字符串表的偏移和其长度。符号表在 Mach-O 目标文件中的地址可以通过 LC_SYMTAB 加载命令指定的 symoff 找到，对应的符号名称在 stroff ，总共有 nsyms 条符号信息
    
    for (uint32_t iCmd = 0; iCmd < header->ncmds; iCmd++) {
        const struct load_command* loadCmd = (struct load_command*)cmdPtr;
        if (loadCmd->cmd == LC_SYMTAB) {
            const struct symtab_command* symtabCmd = (struct symtab_command*)cmdPtr;
            // 符号表的地址 = 基址 + 符号表偏移量
            const CZB_NLIST* symbolTable = (CZB_NLIST *)(segmentBase + symtabCmd->symoff);
            // string表的地址 = 基址 + string表偏移量
            const uintptr_t stringTable = segmentBase + symtabCmd->stroff;
            //            struct nlist {
            //                union {
            //#ifndef __LP64__
            //                    char *n_name;    /* for use when in-core */
            //#endif
            //                    uint32_t n_strx;    /* index into the string table */
            //                } n_un;
            //                uint8_t n_type;        /* type flag, see below */
            //                uint8_t n_sect;        /* section number or NO_SECT */
            //                int16_t n_desc;        /* see <mach-o/stab.h> */
            //                uint32_t n_value;    /* value of this symbol (or stab offset) */
            //            };
            for (uint32_t iSym = 0; iSym < symtabCmd->nsyms; iSym++) {
                // if n_value is 0, the symble is refer to an external object.
//                addr >= symbol.value; 因为addr是某个函数中的一条指令地址，它应该大于等于这个函数的入口地址，也就是对应符号的值；symbol.value is nearest to addr; 离指令地址addr更近的函数入口地址，才是更准确的匹配项；所以遍历symbolTable获取所有的symbol.value 与addressWithSlide比较，得到一个最接近于addressWithSlide 的symbol.value
                if (symbolTable[iSym].n_value != 0) {
                    uintptr_t symbolBase = symbolTable[iSym].n_value;
                    uintptr_t currentDistance = addressWithSlide - symbolBase;
                    if ((addressWithSlide >= symbolBase) && (currentDistance <= bestDistance)) {
                        bestMatch = symbolTable + iSym;
                        bestDistance = currentDistance;
                    }
                }
            }
            if (bestMatch != NULL) {
//                info->dli_saddr = (void*)(bestMatch->n_value + imageVMAddrSlide);得到最接近于address的符号地址（symbol address）address - symbol address = slide，这里的slide正是crash 堆栈中的slide
                info->dli_saddr = (void*)(bestMatch->n_value + imageVMAddrSlide);
                info->dli_sname = (char*)((intptr_t)stringTable + (intptr_t)bestMatch->n_un.n_strx);
                if (*info->dli_sname == '_') {
                    info->dli_sname++;
                }
                // This happens if all symbols have been stripped.
                if (info->dli_saddr == info->dli_fbase && bestMatch->n_type == 3) {
                    info->dli_sname = NULL;
                }
                break;
            }
        }
        cmdPtr += loadCmd->cmdsize;
    }
    return true;
}

///*
// * The 32-bit mach header appears at the very beginning of the object file for
// * 32-bit architectures.
// */
//struct mach_header {
//    uint32_t    magic;        /* mach magic number identifier */
//    cpu_type_t    cputype;    /* cpu specifier */
//    cpu_subtype_t    cpusubtype;    /* machine specifier */
//    uint32_t    filetype;    /* type of file */
//    uint32_t    ncmds;        /* number of load commands */
//    uint32_t    sizeofcmds;    /* the size of all the load commands */
//    uint32_t    flags;        /* flags */
//};
uint32_t czb_imageIndexContainingAddress(const uintptr_t address) {
    const uint32_t imageCount = _dyld_image_count();
    const struct mach_header* header = 0;
    
    for (uint32_t iImg = 0; iImg < imageCount; iImg++) {
        header = _dyld_get_image_header(iImg);
        if (header != NULL) {
            // Look for a segment command with this address within its range
            uintptr_t addressWSlide = address - (uintptr_t)_dyld_get_image_vmaddr_slide(iImg);
            uintptr_t cmdPtr = czb_firstCmdAfterHeader(header);
            if (cmdPtr == 0) {
                continue;
            }
            for (uint32_t iCmd = 0; iCmd < header->ncmds; iCmd++) {
                const struct load_command* loadCmd = (struct load_command*)cmdPtr;
                if (loadCmd->cmd == LC_SEGMENT) {
                    const struct segment_command* segCmd = (struct segment_command*)cmdPtr;
                    if (addressWSlide >= segCmd->vmaddr && addressWSlide < segCmd->vmaddr + segCmd->vmsize) {
                        return iImg;
                    }
                }
                else if (loadCmd->cmd == LC_SEGMENT_64) {
                    const struct segment_command_64* segCmd = (struct segment_command_64*)cmdPtr;
                    if(addressWSlide >= segCmd->vmaddr &&
                       addressWSlide < segCmd->vmaddr + segCmd->vmsize) {
                        return iImg;
                    }
                }
                cmdPtr += loadCmd->cmdsize;
            }
        }
    }
    return UINT_MAX;
}

///*
// * The 32-bit mach header appears at the very beginning of the object file for
// * 32-bit architectures.
// */
//struct mach_header {
//    uint32_t    magic;        /* mach magic number identifier */
//    cpu_type_t    cputype;    /* cpu specifier */
//    cpu_subtype_t    cpusubtype;    /* machine specifier */
//    uint32_t    filetype;    /* type of file */
//    uint32_t    ncmds;        /* number of load commands */
//    uint32_t    sizeofcmds;    /* the size of all the load commands */
//    uint32_t    flags;        /* flags */
//};
uintptr_t czb_firstCmdAfterHeader(const struct mach_header* const header) {
    switch (header->magic) {
        case MH_MAGIC:
        case MH_CIGAM:
            return (uintptr_t)(header + 1);
        case MH_MAGIC_64:
        case MH_CIGAM_64:
            return (uintptr_t)(((struct mach_header_64*)header) + 1);
        default:
            return 0; // Header is corrupt
    }
}

//__LINKEDIT段 含有为动态链接库使用的原始数据，比如符号，字符串，重定位表条目等等
//阅读下面的代码之前，先来看一个计算公式
//链接时程序的基址 = __LINKEDIT.VM_Address – __LINKEDIT.File_Offset + silde的改变值
//这里出现了一个 slide ，那么 slide 是啥呢？先看一下 ASLR
//ASLR：Address space layout randomization ，将可执行程序随机装载到内存中,这里的随机只是偏移，而不是打乱，具体做法就是通过内核将 Mach-O 的段“平移”某个随机系数。 slide 正是 ASLR 引入的偏移
//也就是说程序的基址等于 __LINKEDIT 的地址减去偏移量，然后再加上 ASLR 造成的偏移
// 我们设定segmentBase = __LINKEDIT.VM_Address – __LINKEDIT.File_Offset
// 这里我们返回 segmentBase
uintptr_t czb_segmentBaseOfImageIndex(const uint32_t idx) {
    const struct mach_header* header = _dyld_get_image_header(idx);
    
    // Look for a segment command and return the file image address
    uintptr_t cmdPtr = czb_firstCmdAfterHeader(header);
    if (cmdPtr == 0) {
        return 0;
    }
    for (uint32_t i = 0; i < header->ncmds; i++) {
        const struct load_command* loadCmd = (struct load_command *)cmdPtr;
        if (loadCmd->cmd == LC_SEGMENT) {
            const struct segment_command* segmentCmd = (struct segment_command*)cmdPtr;
            if (strcmp(segmentCmd->segname, SEG_LINKEDIT) == 0) {
                return segmentCmd->vmaddr - segmentCmd->fileoff;
            }
        }
        else if (loadCmd->cmd == LC_SEGMENT_64) {
            const struct segment_command_64* segmentCmd = (struct segment_command_64*)cmdPtr;
            if(strcmp(segmentCmd->segname, SEG_LINKEDIT) == 0) {
                return (uintptr_t)(segmentCmd->vmaddr - segmentCmd->fileoff);
            }
        }
        cmdPtr += loadCmd->cmdsize;
    }
    return 0;
}


#pragma mark Convert NSThread to Mach thread
thread_t czb_machThreadFromNSThread(NSThread *nsthread) {
    char name[256];
    mach_msg_type_name_t count;
    thread_act_array_t list;
    task_threads(mach_task_self(), &list, &count);
    
    NSTimeInterval currentTimestamp = [[NSDate date] timeIntervalSince1970];
    NSString *originName = [nsthread name];
    [nsthread setName:[NSString stringWithFormat:@"%f", currentTimestamp]];
    
    if ([nsthread isMainThread]) {
        return (thread_t)main_thread_id;
    }
    
    for (int i = 0; i < count; ++i) {
        pthread_t pt = pthread_from_mach_thread_np(list[i]);
        if ([nsthread isMainThread]) {
            if (list[i] == main_thread_id) {
                return list[i];
            }
        }
        
        if (pt) {
            name[0] = '\0';
            pthread_getname_np(pt, name, sizeof name);
            if (!strcmp(name, [nsthread name].UTF8String)) {
                [nsthread setName:originName];
                return list[i];
            }
        }
    }
    
    [nsthread setName:originName];
    return mach_thread_self();
}

#pragma mark logbacktrace

NSString* czb_logBacktraceEntry(const int entryNum, const uintptr_t address, const Dl_info* const dlInfo) {
    char faddrBuff[20];
    char saddrBuff[20];
    
    const char* fname = czb_lastPathEntry(dlInfo->dli_fname);
    if (fname == NULL) {
        sprintf(faddrBuff, POINTER_FMT, (uintptr_t)dlInfo->dli_fbase);
        fname = faddrBuff;
    }
    uintptr_t offset = address - (uintptr_t)dlInfo->dli_saddr;
    const char* sname = dlInfo->dli_sname;
    if (sname == NULL) {
        sprintf(saddrBuff, POINTER_SHORT_FMT, (uintptr_t)dlInfo->dli_fbase);
        sname = saddrBuff;
        offset = address - (uintptr_t)dlInfo->dli_fbase;
    }
    
    return [NSString stringWithFormat:@"%-30s  0x%08" PRIxPTR " %s + %lu\n" ,fname, (uintptr_t)address, sname, offset];;
}

const char* czb_lastPathEntry(const char* const path) {
    if (path == NULL) {
        return NULL;
    }
    
    char* lastFile = strrchr(path, '/');
    return lastFile == NULL ? path : lastFile + 1;
}

@end
