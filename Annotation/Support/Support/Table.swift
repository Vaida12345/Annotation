//
//  Table.swift
//  cmd
//
//  Created by Vaida on 12/5/21.
//

import Foundation

struct Table<T>: Codable, Equatable, Hashable where T: Hashable, T: CustomStringConvertible, T: Codable {
    
    //MARK: - Basic Instance Properties
    
    /// The values of the table.
    var value: [[T]]
    
    
    //MARK: - Instance Properties
    
    /// The dictionary with the first column as key.
    var dictionary: [T: [T]] {
        get {
            var dictionary: [T: [T]] = [:]
            
            var index = -1
            while index + 1 < self.value.count {
                index += 1
                let i = self.value[index]
                
                dictionary[i.first!] = Array(i[1..<i.count])
            }
            return dictionary
        }
        set {
            var value: [[T]] = []
            for i in newValue {
                value.append([i.key] + i.value)
            }
            self.value = value
        }
    }
    
    /// Express the table in a matrix.
    var matrix: [[T]] {
        get { return value }
        set { self.value = newValue }
    }
    
    /// The size of the table.
    var size: Size {
        return Size(width: self.matrix.first?.count ?? 0, height: self.matrix.count)
    }
    
    
    //MARK: - Type Properties
    
    
    
    //MARK: - Initializers
    
    init(_ value: [[T]] = []) {
        self.value = value
    }
    
    /// The dictionary with the first column as key.
    init(dictionary: [T: [T]]) {
        self.value = []
        self.dictionary = dictionary
    }
    
    init(contentsOfFile: String, hasTitle: Bool) throws where T == String {
        let contents: String = try String(contentsOfFile: contentsOfFile)
        
        var matrix = contents.components(separatedBy: "\n").map({ $0.components(separatedBy: ",") })
        if matrix.last! == [] || matrix.last! == [""] {
            matrix.removeLast()
        }
        self.value = matrix
    }
    
    
    //MARK: - Instance Methods
    
    /// Append a column to the table.
    ///
    /// - precondition: The number of items in the column should be equal to the number of rows in the table.
    mutating func addColumn(_ column: [T]) {
        precondition(column.count == matrix.count)
        
        var i = -1
        while i + 1 < column.count {
            i += 1
            
            value[i].append(column[i])
        }
    }
    
    /// Append a row to the table.
    mutating func addRow(_ row: [T]) {
        self.append(row)
    }
    
    /// Append a row to the table.
    mutating func append(_ row: [T]) {
        self.value.append(row)
    }
    
    /// The column at the given index.
    func column(at index: Int) -> [T] {
        return self.transposed().row(at: index)
    }
    
    /// The columns at the given range.
    func column(at indexes: ClosedRange<Int>) -> [[T]] {
        return self.transposed().rows(at: indexes)
    }
    
    /// The columns at the given range.
    func column(at indexes: Range<Int>) -> [[T]] {
        return self.transposed().rows(at: indexes)
    }
    
    /// The index of column.
    func firstIndex(ofColumn column: [T]) -> Int? {
        return self.transposed().matrix.firstIndex(of: column)
    }
    
    /// The indexes of column.
    func firstIndex(ofColumns columns: [[T]]) -> Range<Int>? {
        return self.transposed().matrix.firstIndex(of: columns)
    }
    
    /// The index of column.
    func firstIndex(ofRow row: [T]) -> Int? {
        return self.matrix.firstIndex(of: row)
    }
    
    /// The indexes of column.
    func firstIndex(ofRows rows: [[T]]) -> Range<Int>? {
        return self.matrix.firstIndex(of: rows)
    }
    
    /// Inserts a new column at the specified position.
    ///
    /// - precondition: The number of items in the column should be equal to the number of rows in the table.
    mutating func insertColumn(_ column: [T], at index: Int) {
        precondition(column.count == matrix.count)
        
        var i = -1
        while i + 1 < column.count {
            i += 1
            
            value[i].insert(column[i], at: index)
        }
    }
    
    /// Inserts a new row at the specified position.
    mutating func insertRow(_ row: [T], at index: Int) {
        self.value.insert(row, at: index)
    }
    
    /// The item at the given coordinate.
    func item(at coordinate: (x: Int, y: Int)) -> T {
        return self.matrix[coordinate.y][coordinate.x]
    }
    
    /// Print the table.
    @discardableResult func print() -> String {
        return printMatrix(matrix: self.matrix)
    }
    
    /// The row at the given index.
    func row(at index: Int) -> [T] {
        return Array(self.matrix[index])
    }
    
    /// The rows at the given indexes.
    func rows(at indexes: ClosedRange<Int>) -> [[T]] {
        return Array(self.matrix[indexes])
    }
    
    /// The rows at the given indexes.
    func rows(at indexes: Range<Int>) -> [[T]] {
        return Array(self.matrix[indexes])
    }
    
    /// Transpose the table.
    func transposed() -> Table {
        var newMatrix: [[T?]] = [[T?]](repeating: [T?](repeating: nil, count: matrix.count), count: matrix.first!.count)
        
        var i = -1
        while i + 1 < matrix.count {
            i += 1
            
            var ii = -1
            while ii + 1 < matrix.first!.count {
                ii += 1
                
                newMatrix[ii][i] = matrix[i][ii]
            }
        }
        return Table(newMatrix.map({ $0.map({ $0! }) }))
    }
    
    /// Write the table to path as csv.
    func write(to item: FinderItem) {
        let value = self.matrix.map({ String($0.reduce("", { $0 + "," + $1.description }).dropFirst()) }).reduce("", { $0 + "\n" + $1 }).dropFirst()
        
        do {
            try value.write(to: item.url, atomically: true, encoding: .utf8)
        } catch {
            Swift.print("table.write(to:) failed with error: \(error)")
        }
    }
    
    /// Write the table to path as csv.
    func write(to path: String) {
        self.write(to: FinderItem(at: path))
    }
    
    
    //MARK: - Type Methods
    
    
    
    //MARK: - Operator Methods
    
    
    
    //MARK: - Comparison Methods
    
    static func == (_ lhs: Self, _ rhs: Self) -> Bool {
        return lhs.matrix == rhs.matrix
    }
    
    
    
    //MARK: - Substructures
    
    
    
    //MARK: - Subscript
    
    subscript(index: Int) -> [T] {
        return self.matrix[index]
    }
    
    subscript(range: Range<Int>) -> [[T]] {
        return Array(self.matrix[range])
    }
    
    subscript(range: ClosedRange<Int>) -> [[T]] {
        return Array(self.matrix[range])
    }
    
}
