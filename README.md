# SnapshotParser
Parser for gson-like parsing/serializing of Firebase-Snapshot-responses in Swift 4.

> (Note: This class is designed for Swift 4 and the Firebase SDK v4.0.0+)


With this Parser you can automatically fill swift objects from your Firebase-Snapshots.
It maps the fields of the json into class members. 
The key of a snapshot is always mapped into the class as an ```id```-member of type ```String```.
If the id is not needed you can just implement the ```ParsableObject``` instead of the ```ParsableSnapshot``` protocol.

The parser guarantees that you typed every name correctly by throwing an exception if a key is typed wrong :)

It is also possible to serialize the objects back into a dictionary, which can be used to update database values.
During the serialisation process the keys of the snapshots are mapped back out of the class.

# Installation
* Just download the swift file and integrate it into the project.
* Implement a class for each snapshot/object.
* Nest as much as you want
* Have fun with the clean API

# Usage

The parser knows five types to interpret the json format from Firebase:

* Snapshot - contains a key and one json-object
* Field - just a primitive field
* Object - a snapshot without key
* List - a list of snapshots
* Dictionary - instead of mapping values to class members they are mapped into a dictionary

The following example is a Snapshot with the key ``-KlkSDA48adWgf4cSAe4"``:

```javascript
"-KlkSDA48adWgf4cSAe4": {
			"name": "name",
			"field1": 10,
			"field2": 7,
			"field3": 23,
			"object":{
				"fieldA":true,
				"fieldB":"text"
			},
			"list": {
				"-KrD41dNnkdq46k6fDPb": {
					"fieldX": 0,
					"fieldY": "some text",
					"FieldZ": true
				},
				"Oklde47E5d4-OghJkl4A": {
					"fieldX": 0,
					"fieldY": "some text",
					"FieldZ": true
				},
				"-KdjDiEjda4875EdsakD": {
					"fieldX": 0,
					"fieldY": "some text",
					"FieldZ": true
				}
			}
```

---

The following code demonstrates all use cases (the code is not linked to the json above):

```swift
    class Main{
        
        func run(){
            //parse single snapshot into an Example
            let exampleObject = try SnapshotParser().parseSnapshot(snap: getSnapshot(),type: Example.self)
            //parse list of snapshots into an Array<Example>
            let exampleObjects = try SnapshotParser().parseAsList(snap: getSnapshot(),type: Example.self)
            //you can also serialize the created objects again
            let dict=SnapshotParser().serialize(object: exampleObject)
            //to change the key name (which is "id" by default) you can create the parser with a custom key
            //but this is not necessary in most cases
            let parser=SnapshotParser(withKey: "yourPrimaryKey") 
        }
    }


    class Example:ParsableSnapshot{
        var id: String? //ParsableSnaphot maps the id into the class
        
        var yourPrimitiveField:String?=nil
        var yourObject:YourObject?=nil      // Here is a Snapshot with an ignored id value
        var yourList:[Something]?=nil       // If there is a list it means that Example contains multiple snapshots
        var yourDict:[String:Bool]?=nil     // A dictionary is always filled with all the bindings which were not explicitly bound
        //...
        
        required init(){} //This is required :D
        
        func bindProperties(binder: SnapshotParser.Binder) {
            // This is the heart of the parser
            // Here you bind the member to the key of the json
            // You don't have to bind everything as long as you provide a dictionary to take the rest of the fields
            // If no dictionary is used you get really nice errors about typos in the names - that is a good thing!
            // So don't use a dictionary unless you need one
         
            binder.bindField(name: "id", field: &id)
            binder.bindField(name: "yourPrimitiveField", field: &yourPrimitiveField)
            binder.bindObject(name: "yourObject", field: &yourObject)
            binder.bindList(name: "yourList", list: &yourList)
            binder.bindDictionary(name: "yourDict", dict: &yourDict)
            //...
        }
    }

    class Something: ParsableSnapshot {
        var id: String?
        
        required init(){}

        func bindProperties(binder: SnapshotParser.Binder) {
            binder.bindField(name: "id", field: &id)
        }
    }

    class YourObject: ParsableObject {
        //object ignores id
        //...
        
        required init(){}
        
        func bindProperties(binder: SnapshotParser.Binder) {
            //...
        }
    }
```

If you have questions feel free to open an issue ;)
