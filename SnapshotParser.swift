//
//  SnapshotParser.swift
//  Snowlink
//
//  Created by Robert Gstöttner on 13/08/2017.
//  Copyright © 2017 appyx. All rights reserved.
//

import Foundation
import FirebaseDatabase


/// This parser parses the snapshot of a firebase reference into a swift class.
/// The destination class has to implement the ParsableObject/ParsableSnapshot protocol.
/// The destination classes can be nested.
///
/// Each field of the snapshot has to be bound to a corresponding field in the class or
/// an error will be thrown.
class SnapshotParser {

    /// Parses the firebase-snapshot and returns a object of the specified type.
    /// The fields/objects/lists can be bound in the method:
    ///
    /// bindProperties(binder: SnapshotParser.Binder)
    func parse<T:ParsableSnapshot>(snap: DataSnapshot, type: T.Type) throws -> T {
        let object = T()
        if let node = snap.value as? [String: Any] {
            return try parseNode(id: snap.key, node: node)
        }
        return object
    }
    
    func parseAsList<T:ParsableSnapshot>(snap:DataSnapshot, type:T.Type) throws -> Array<T> {
        var list=[T]()
        if let value = snap.value as? [String: Any] {
            list=try parseList(list: value)
        }
        return list
    }
    
    
    
    
    

    private func parseNode<T:ParsableSnapshot>(id: String, node: [String: Any]) throws -> T {
        let object = T()
        var binder = Binder(key: "id", value: id)
        object.bindProperties(binder: binder)
        try binder.checkForError()

        for(key, value) in node {
            binder = Binder(key: key, value: value)
            object.bindProperties(binder: binder)
            try binder.checkForError()
        }
        return object
    }

    private func parseList<T:ParsableSnapshot>(list: Any) throws -> Array<T> {
        var result = [T]()
        if let list = list as?[String: Any] {
            for(key, value) in list {
                if let value = value as?[String: Any] {
                    try result.append(parseNode(id: key, node: value))
                }
            }
        }
        return result
    }
    private func parseObject<T:ParsableObject>(node: Any) throws -> T {
        let object = T()
        if let node = node as?[String: Any] {
            for(key, value) in node {
                let binder = Binder(key: key, value: value)
                object.bindProperties(binder: binder)
                try binder.checkForError()
            }
        }
        return object
    }

    /// The binder is used to assign the parsed values to their corresponding fields/objects/lists.
    class Binder {

        private let parser = SnapshotParser()
        private let key: String
        private var value: Any
        private var isBound = false
        private var error: ParseError? = nil

        fileprivate init(key: String, value: Any) {
            self.key = key
            self.value = value
        }

        fileprivate func checkForError() throws {
            if(isBound == false) {
                if let error = error {
                    throw error
                } else {
                    throw ParseError.bindingFailed("unable to bind the property: \(key)")
                }
            }
        }

        /// Binds the value of a primitive type identified by the name to the corresponding field.
        /// The field is passed by reference.
        /// If the name does not match an error will be thrown.
        func bindField<T>(name: String, field: inout T?) {
            if(key == name) {
                field = value as? T
                isBound = true
            }
        }

        /// Binds the value of a primitive type identified by the name to the corresponding field.
        /// The field is passed by reference.
        /// If the name does not match an error will be thrown.
        /// Additionally it is possible to define a mapper function to convert
        /// the primitive type of the value into some other type.
        ///
        /// This is necessary if the resulting field cannot be cast into the desired type.
        /// (Maybe it requires a constructor to create an instance e.g. enum)
        ///
        func bindField<T>(name: String, field: inout T?, mapper: (Any) -> T?) {
            if(key == name) {
                field = mapper(value)
                isBound = true
            }
        }

        /// Binds the list identified by the name to the correct field.
        /// A list can contain multiple snapshots.
        /// The list is passed by reference.
        /// The method parses the contents of the list recursivley
        ///
        /// If the name does not match an error will be thrown.
        func bindList<T:ParsableSnapshot>(name: String, list: inout Array<T>?) {
            if(key == name) {
                do {
                    try list = parser.parseList(list: value)
                    isBound = true
                }
                catch let error {
                    self.error = error as? ParseError
                }
            }
        }

        /// Binds the object identified by the name to the correct field.
        /// The object is a snapshot where the key is ignored
        /// The object is passed by reference.
        /// The method parses the contents of the list recursivley
        ///
        /// If the name does not match an error will be thrown.
        func bindObject<T:ParsableObject>(name: String, field: inout T?) {
            if(key == name) {
                do {
                    try field = parser.parseObject(node: value)
                    isBound = true
                } catch let error {
                    self.error = error as? ParseError
                }
            }
        }

        /// Binds all previously unbinded values and their keys into a dictionary.
        /// This method can be used as a fallback mechanism if some values were not bound.
        /// This is useful if there are keys in the snapshot which are generated hash codes for example or
        /// if the name of the key is not known in advance.
        ///
        /// This method throws an exception if different types are used for key-value-pairs.
        func bindDictionary<K, V>(name:String, dict: inout [K: V]?) {
            if let value = value as? V, let key = key as? K{
                if(dict==nil){
                    dict=[K:V]()
                }
                dict?.updateValue(value, forKey: key)
                isBound=true
            }else{
                self.error = ParseError.bindingFailed("unable to bind the dictionary named: \(name)")
            }
        }
    }
    
    class List<T:ParsableSnapshot>:ParsableSnapshot {
        var id: String?=nil
        var list:[T]?=nil
        
        required init(){}
        
        func bindProperties(binder: SnapshotParser.Binder) {
            binder.bindList(name: "list", list: &list)
        }
        
        func getList()->Array<T>?{
            return list
        }
        
        
        
        
    }

    enum ParseError: Error {
        case bindingFailed(String)
    }

}

/// Used for parsing a snapshot into an swift object.
/// A snapshot contains a key(String) and a value([String:Any])
///
/// e.g: "123456789123": {"name":"bob", "isFancy":true, "counter":13}
///
/// The final object has to contain at least an id-property for the key.
protocol ParsableSnapshot: ParsableObject {
    var id: String? { get set }
}

/// Used for parsing an object without a key into an object.
/// Same as the ParsableSnapshot but the key is ignored.
protocol ParsableObject {
    init()
    func bindProperties(binder: SnapshotParser.Binder)
}


