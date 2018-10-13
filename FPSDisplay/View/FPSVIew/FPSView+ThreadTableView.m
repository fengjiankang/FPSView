//
//  FPSView+ThreadTableView.m
//  FPSDisplay
//
//  Created by kangya on 2018/10/13.
//  Copyright © 2018年 kangya. All rights reserved.
//

#import "FPSView+ThreadTableView.h"

@implementation FPSView (ThreadTableView)

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    // 从tableview的重用池里通过cellID取一个cell
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:threadCellId];
    if (cell == nil) {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:threadCellId];
    }
    // 设置 cell 的标题
    cell.textLabel.text = [NSString stringWithFormat:@"id: %@", self.threadDataSource[indexPath.row][@"id"]];
    // 设置 cell 的副标题
    cell.detailTextLabel.text = [NSString stringWithFormat:@"名称:%@", self.threadDataSource[indexPath.row][@"name"]];
    
    [cell layoutSubviews];

    return cell;
}

- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.threadDataSource.count;
}

@end
