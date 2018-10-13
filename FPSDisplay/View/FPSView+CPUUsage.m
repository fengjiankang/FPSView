//
//  FPSView+CPUUsage.m
//  FPSDisplay
//
//  Created by kangya on 2018/10/13.
//  Copyright © 2018年 kangya. All rights reserved.
//

#import "FPSView+CPUUsage.h"

@implementation FPSView (CPUUsage)

static mach_port_t main_thread_id;


//struct thread_basic_info {
//    time_value_t    user_time;      /* user run time */
//    time_value_t    system_time;    /* system run time */
//    integer_t       cpu_usage;      /* scaled cpu usage percentage */
//    policy_t        policy;         /* scheduling policy in effect */
//    integer_t       run_state;      /* run state (see below) */
//    integer_t       flags;          /* various flags (see below) */
//    integer_t       suspend_count;  /* suspend count for thread */
//    integer_t       sleep_time;     /* number of seconds that thread
//                                     has been sleeping */
//};

//kern_return_t task_threads
//(
// task_inspect_t target_task,
// thread_act_array_t *act_list,
// mach_msg_type_number_t *act_listCnt
// );
//
//kern_return_t thread_info
//(
// thread_inspect_t target_act,
// thread_flavor_t flavor,
// thread_info_t thread_info_out,
// mach_msg_type_number_t *thread_info_outCnt
// );


-(double)getCpusageOfAllThread {
    double usageRatio = 0;
    thread_info_data_t thInfo;
    thread_act_array_t threads;
    thread_basic_info_t basic_info_t;
    mach_msg_type_number_t count = 0;
    mach_msg_type_number_t thread_info_count = THREAD_INFO_MAX;
    
    if (task_threads(mach_task_self(), &threads, &count) == KERN_SUCCESS) {
        for (int idx = 0; idx < count; idx++) {
            if (thread_info(threads[idx], THREAD_BASIC_INFO, (thread_info_t)thInfo, &thread_info_count) == KERN_SUCCESS) {
                basic_info_t = (thread_basic_info_t)thInfo;
                // select the thread that isn't idle
                if (!(basic_info_t->flags & TH_FLAGS_IDLE)) {
                    usageRatio += basic_info_t->cpu_usage / (double)TH_USAGE_SCALE;
                }
            }
        }
         assert(vm_deallocate(mach_task_self(), (vm_address_t)threads, count * sizeof(thread_t)) == KERN_SUCCESS);
    }
    return usageRatio * 100;
}

+(void)load {
    main_thread_id = mach_thread_self();
}

-(double)getCpusageOfMainThread {
    double usageRatio = 0;
    thread_info_data_t thInfo;
    thread_act_array_t threads;
    thread_basic_info_t basic_info_t;
    mach_msg_type_number_t count = 0;
    mach_msg_type_number_t thread_info_count = THREAD_INFO_MAX;

    if (task_threads(mach_task_self(), &threads, &count) == KERN_SUCCESS) {
        for (int idx = 0; idx < count; idx++) {
            if (threads[idx] == main_thread_id) {
                if (thread_info(threads[idx], THREAD_BASIC_INFO, (thread_info_t)thInfo, &thread_info_count) == KERN_SUCCESS) {
                    basic_info_t = (thread_basic_info_t)thInfo;
                    // select the thread that isn't idle
                    if (!(basic_info_t->flags & TH_FLAGS_IDLE)) {
                        usageRatio += basic_info_t->cpu_usage / (double)TH_USAGE_SCALE;
                    }
                }
            }
        }
        assert(vm_deallocate(mach_task_self(), (vm_address_t)threads, count * sizeof(thread_t)) == KERN_SUCCESS);
    }
    return usageRatio * 100;
}

@end
