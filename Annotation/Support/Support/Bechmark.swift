//
//  Bechmark.swift
//
//
//  Created by Vaida on 9/28/21.
//  Copyright © 2021 Vaida. All rights reserved.
//

import Foundation

/// A structure servers to find the time for each iteration.
///
/// Initialize with, for example:
///
///     var bench = Benchmark(items: [
///         .init(title: "Int", sequence: [Int](1...10), action: { item in
///             let _ = item as! Int
///         })
///     ])
///
/// Then, run with:
///
///     bench.run()
///
/// - Important:
/// If you, for example, append items from the sequence. Remove the first item of the resulting sequence.
struct Benchmark {
    
    struct Item {
        var title: String
        var upperBound: Int
        var action: (_ i: Int) -> Void
        var results: [Double] = []
        
        mutating func run() {
            guard results.isEmpty else { return }
            var intervals: [Double] = []
            var counter = 0
            while counter < upperBound {
                let date = Date()
                self.action(counter)
                let interval = date.distance(to: Date())
                intervals.append(interval)
                counter += 1
            }
            self.results = intervals
        }
        
        mutating func saveResults() {
            let item = FinderItem(at: "/Users/vaida/Documents/Xcode Data/Benchmark Results/\(title).json")
            let path = item.generateOutputPath()
            self.run()
            try! FinderItem.saveJSON(self.results, to: path)
        }
        
        init(title: String, upperBound: Int, action: @escaping (_ i: Int) -> Void) {
            self.title = title
            self.upperBound = upperBound
            self.action = action
        }
        
        init(fromResultsAt path: String, name: String? = nil) {
            let results = try! FinderItem.loadJSON(from: path, type: [Double].self)
            self.results = results
            self.title = name ?? FinderItem(at: path).fileName
            self.upperBound  = 0
            self.action = { _ in  }
        }
    }
    
    var items: [Item]
    
    mutating func run() {
        let date = Date()
        self.items.first!.action(self.items.first!.upperBound - 1)
        let interval = date.distance(to: Date())
        print("benchmark.run(): It would take around \((Double(self.items.count * self.items.first!.upperBound) * interval).expressedAsTime())")
        
        var pointsSets = [Canvas.PointSet(points: [Point.zero], name: "")]
        
        var i = -1
        while i + 1 < items.count {
            i += 1
            
            self.items[i].run()
            var points: [Point] = []
            
            var ii = -1
            while ii + 1 < self.items[i].results.count {
                ii += 1
                
                points.append(Point(x: Double(ii), y: self.items[i].results[ii]))
            }
            pointsSets.append(Canvas.PointSet(points: points, name: self.items[i].title))
        }
        
        let canvas = Canvas(points: pointsSets)
        canvas.lineWidth = {()-> Double in
            let lineWidth = Double(canvas.frame.width) / Double(self.items.map{ $0.upperBound }.max() ?? 1) / 2
            if lineWidth >= 2 { return 2 }
            if lineWidth <= 0.2 { return 0.2 }
            return lineWidth
        }()
        
        canvas.draw()
        
        print("\n----- results -----")
        var matrix: [[String]] = [["Title", "Time Taken", "Min Interval", "Max Interval", "Average"]]
        
        var index = -1
        while index + 1 < items.count {
            index += 1
            let i = items[index]
            
            var content: [String] = []
            content.append(i.title)
            content.append(i.results.reduce(0, +).expressedAsTime())
            content.append(i.results.filter({ $0 != 0 }).min()?.expressedAsTime() ?? "nan")
            content.append(i.results.max()?.expressedAsTime() ?? "nan")
            content.append(i.results.average().expressedAsTime())
            matrix.append(content)
        }
        printMatrix(matrix: matrix, transpose: true)
        print("\n----- raw data -----")
        printMatrix(matrix: items.map({ [$0.title] + $0.results.map({ String($0) }) }), transpose: true)
    }
    
    mutating func saveResults() {
        
        var i = -1
        while i + 1 < items.count {
            i += 1
            
            self.items[i].saveResults()
        }
        print("results saved to: /Users/vaida/Documents/Xcode Data/Benchmark Results/")
    }
    
    init(items: [Item], repeatingCount: Int = 1) {
        var content: [Item] = []
        
        var index = -1
        while index + 1 < repeatingCount {
            index += 1
            
            var index = -1
            while index + 1 < items.count {
                index += 1
                let i = items[index]
                
                content.append(i)
            }
        }
        self.items = content
    }
}
