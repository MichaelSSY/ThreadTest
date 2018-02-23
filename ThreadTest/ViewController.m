//
//  ViewController.m
//  ThreadTest
//
//  Created by weiyun on 2018/2/23.
//  Copyright © 2018年 孙世玉. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self test];
}
- (void)test
{
    NSLog(@"1");
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"2 %@",[NSThread currentThread]);
    });
    NSLog(@"3");
    
    //最后只输出1，然后就卡在 dispatch_sync 这里了，分析如下：
    
    //dispatch_sync表示是一个同步线程，会阻塞当前线程，然后把Block中任务添加到队列中执行，等到Block中任务完成后才会让当前线程继续执行。
    //dispatch_get_main_queue表示主线程中的主队列； 首先执行任务1，打印出1，程序遇到dispatch_sync会立即阻塞当前主线程，把任务2放到主队列中， 等待任务2执行完，再执行任务3。可是主队列是按照FIFO原则执行任务，此时主队列中任务3排在任务2之前，所以要等到任务3执行完后才能执行任务2，这就会造成他们进入互相等待的局面，从而产生死锁。避免死锁的方法是在使用dispatch_sync执行任务时，传入参数的队列不要和当前线程的队列是一样的。
    
    //串行队列+dispatch_sync：在当前线程里顺序执行。
    
    //串行队列+dispatch_async：会新建一个子线程，在同一个子线程里顺序执行。
    
    //并发队列+dispatch_sync：在当前线程里顺序执行。
    
    //并发队列+dispatch_async：会创建多个线程，任务在不同的子线程里无须并发执行。
    
    //系统的全局队列和并发队列一样，只不过不能指定队列名。
    
    //主队列是个串行队列，dispatch_async 任务都在主线程执行，dispatch_sync会造成主线程死锁。
}

// 1.通过NSThread类开辟子线程
- (void)method1
{
    // 创建线程对象
    NSThread *thread1 = [[NSThread alloc] initWithTarget:self selector:@selector(eat) object:nil];
    thread1.name = @"sun";
    
    // 手动开启
    [thread1 start];
    
    // 创建线程对象自动开启，无返回值
    [NSThread detachNewThreadSelector:@selector(eat) toTarget:self withObject:nil];
    
    // 手动取消线程
    // [thread1 cancel];
    
    
    // 回到主线程
    [self performSelectorOnMainThread:@selector(mainQueue) withObject:nil waitUntilDone:NO];
    
}

// 2.通过NSOperationQueue开辟子线程
- (void)method2
{
    // NSInvocationOperation 创建对象(多个)
    NSInvocationOperation *invocation1 = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(eat) object:nil];
    NSInvocationOperation *invocation2 = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(eat) object:nil];

    // NSBlockOperation 创建任务
    __weak typeof(self) weakSelf = self;
    //__weak ViewController *weakSelf = self;
    NSBlockOperation *blockOperation = [NSBlockOperation blockOperationWithBlock:^{
        [weakSelf eat]; // 任务1
    }];
    [blockOperation addExecutionBlock:^{
        [weakSelf eat]; // 任务2
    }];
    [blockOperation addExecutionBlock:^{
        [weakSelf eat]; // 任务3
    }];
    
    // 创建 operationQueue 队列
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];

    //NSOperationQueue 有一个属性 maxConcurrentOperationCount 最大并发数，用来设置最多可以让多少个任务同时执行。当你把它设置为 1 的时候，变为串行队列！

    queue.maxConcurrentOperationCount = 1;

    [queue addOperation:invocation1];
    [queue addOperation:invocation2];

    [queue addOperation:blockOperation];

    // 取消任务
    //[invocation1 cancel];
    //[blockOperation cancel];
    
    // 开启
//    [invocation1 start];
//    [invocation2 start];
//    [blockOperation start];
    
    [blockOperation setCompletionBlock:^{
        NSLog(@"都完成了");
    }];
    // 回到主线程
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [weakSelf mainQueue];
    }];
    
    
}

// 2.通过GCD开辟子线程
- (void)method3
{
    __weak typeof(self)weakSelf = self;
    
    //***************** 自定义串行队列 *****************//
    // 串行队列 SERIAL
    dispatch_queue_t queue = dispatch_queue_create("SERIAL", DISPATCH_QUEUE_SERIAL);
    dispatch_async(queue, ^{
        // 异步任务 分线程中执行 不会阻塞主线程
        //[weakSelf eat];
    });
    dispatch_sync(queue, ^{
        // 同步任务 主线程中执行 会阻塞当前线程
        //[weakSelf eat];
    });
    
    
    
    //***************** 自定义并行队列 *****************//
    // 并行队列 CONCURRENT
    dispatch_queue_t queue2 = dispatch_queue_create("CONCURRENT", DISPATCH_QUEUE_CONCURRENT);
    for (int i = 0; i < 10; i ++) {
        dispatch_async(queue2, ^{
            NSLog(@"%zd",i);
        });
    }
    
    // 几个线程执行完后得到通知
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_notify(group, queue2, ^{
        NSLog(@"queue2的所有任务都执行完了");
    });
    
    
    //****************** 获取主线程 ******************//
    // 获取主线程(获取自带的串行队列) dispatch_sync会造成主线程死锁。
    dispatch_queue_t queue3 = dispatch_get_main_queue();
    dispatch_async(queue3, ^{
        //[weakSelf eat];
    });
    
    
    // 获取系统的并行队列(4个)
    dispatch_queue_t queue4 = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue4, ^{
        //[weakSelf eat];
    });
    
    //dispatch_async_f(queue2, "哈哈", function);
}

void function(void *context){
    NSLog(@"%s", context);
    NSLog(@"%@",[NSThread currentThread]);
}

- (void)eat
{
    NSLog(@"%@",[NSThread currentThread]);
}
- (void)mainQueue
{
    NSLog(@"主线程 %@",[NSThread currentThread]);
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
