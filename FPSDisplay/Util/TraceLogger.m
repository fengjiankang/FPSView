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
#define BS_NLIST struct nlist_64
#else
#define TRACE_FMT         "%-4d%-31s 0x%08lx %s + %lu"
#define POINTER_FMT       "0x%08lx"
#define POINTER_SHORT_FMT "0x%lx"
#define BS_NLIST struct nlist
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

+(void)getThreadCount {
    char name[256];
    mach_msg_type_name_t count;
    thread_act_array_t list;
    task_threads(mach_task_self(), &list, &count);
    
    NSLog(@"获取线程个数：%d, %d", count, main_thread_id);
    
    for (int i = 0 ; i < count; i++) {
        
        pthread_t pt = pthread_from_mach_thread_np(list[i]);
        
        if (pt) {
            name[0] = '\0';
            pthread_getname_np(pt, name, sizeof name);
            if (!strcmp(name, [[NSThread currentThread] name].UTF8String)) {
            }
        }
        
        NSLog(@"thread is %s", name);
    }
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
    
    return [resultString copy];
}

#pragma mark Symbolicate
void czb_symbolicate(const uintptr_t* const backtraceBuffer, Dl_info* const symbolsBuffer, const int numEntries, const int skippedEntries) {
    int i = 0;
    
    if (!skippedEntries && i < numEntries) {
        czb_dladdr(backtraceBuffer[i], &symbolsBuffer[i]);
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
    const uintptr_t segmentBase = czb_segmentBaseOfImageIndex(idx) + imageVMAddrSlide;
    return false;
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

@end
