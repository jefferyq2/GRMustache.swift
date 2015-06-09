// The MIT License
//
// Copyright (c) 2015 Gwendal Roué
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


import XCTest
import Mustache

class FilterTests: XCTestCase {
    
    func testFilterCanChain() {
        let box = Box([
            "name": Box("Name"),
            "uppercase": Box(Filter { (string: String?) -> MustacheBox in
                return Box(string?.uppercaseString)
            }),
            "prefix": Box(Filter { (string: String?) -> MustacheBox in
                return Box("prefix\(string!)")
            })
            ])
        let template = try! Template(string:"<{{name}}> <{{prefix(name)}}> <{{uppercase(name)}}> <{{prefix(uppercase(name))}}> <{{uppercase(prefix(name))}}>")
        let rendering = try! template.render(box)
        XCTAssertEqual(rendering, "<Name> <prefixName> <NAME> <prefixNAME> <PREFIXNAME>")
    }
    
    func testScopedValueAreExtractedOutOfAFilterExpression() {
        let template = try! Template(string:"<{{f(object).name}}> {{#f(object)}}<{{name}}>{{/f(object)}}")
        var box: MustacheBox
        var rendering: String
        
        box = Box([
            "object": Box(["name": "objectName"]),
            "name": Box("rootName"),
            "f": Box(Filter { (box: MustacheBox) -> MustacheBox in
                return box
            })
            ])
        rendering = try! template.render(box)
        XCTAssertEqual(rendering, "<objectName> <objectName>")
        
        box = Box([
            "object": Box(["name": "objectName"]),
            "name": Box("rootName"),
            "f": Box(Filter { (_: MustacheBox) -> MustacheBox in
                return Box(["name": "filterName"])
            })
            ])
        rendering = try! template.render(box)
        XCTAssertEqual(rendering, "<filterName> <filterName>")
        
        box = Box([
            "object": Box(["name": "objectName"]),
            "name": Box("rootName"),
            "f": Box(Filter { (_: MustacheBox) -> MustacheBox in
                return Box(true)
            })
            ])
        rendering = try! template.render(box)
        XCTAssertEqual(rendering, "<> <rootName>")
    }
    
    func testFilterArgumentsDoNotEnterSectionContextStack() {
        let box = Box([
            "test": Box("success"),
            "filtered": Box(["test": "failure"]),
            "filter": Box(Filter { (_: MustacheBox, _: NSErrorPointer) -> MustacheBox? in
                return Box(true)
            })])
        let template = try! Template(string:"{{#filter(filtered)}}<{{test}} instead of {{#filtered}}{{test}}{{/filtered}}>{{/filter(filtered)}}")
        let rendering = try! template.render(box)
        XCTAssertEqual(rendering, "<success instead of failure>")
    }
    
    func testFilterNameSpace() {
        let doubleFilter = Box(Filter { (x: Int?) -> MustacheBox in
            return Box((x ?? 0) * 2)
        })
        let box = Box([
            "x": Box(1),
            "math": Box(["double": doubleFilter])
            ])
        let template = try! Template(string:"{{ math.double(x) }}")
        let rendering = try! template.render(box)
        XCTAssertEqual(rendering, "2")
    }
    
    func testFilterCanReturnFilter() {
        let filterValue = Box(Filter { (string1: String?) -> MustacheBox in
            return Box(Filter { (string2: String?) -> MustacheBox in
                    return Box("\(string1!)\(string2!)")
                })
            })
        let box = Box([
            "prefix": Box("prefix"),
            "value": Box("value"),
            "f": filterValue])
        let template = try! Template(string:"{{f(prefix)(value)}}")
        let rendering = try! template.render(box)
        XCTAssertEqual(rendering, "prefixvalue")
    }
    
    func testImplicitIteratorCanReturnFilter() {
        let box = Box(Filter { (_: MustacheBox) -> MustacheBox in
            return Box("filter")
        })
        let template = try! Template(string:"{{.(a)}}")
        let rendering = try! template.render(box)
        XCTAssertEqual(rendering, "filter")
    }
    
    func testMissingFilterError() {
        let box = Box([
            "name": Box("Name"),
            "replace": Box(Filter { (_: MustacheBox) -> MustacheBox in
                return Box("replace")
            })
        ])
        
        var template = try! Template(string:"<{{missing(missing)}}>")
        var error: NSError?
        var rendering: String?
        do {
            rendering = try template.render(box)
        } catch var error1 as NSError {
            error = error1
            rendering = nil
        }
        XCTAssertNil(rendering)
        XCTAssertEqual(error!.domain, GRMustacheErrorDomain)
        XCTAssertEqual(error!.code, GRMustacheErrorCodeRenderingError)
        
        template = try! Template(string:"<{{missing(name)}}>")
        do {
            rendering = try template.render(box)
        } catch var error1 as NSError {
            error = error1
            rendering = nil
        }
        XCTAssertNil(rendering)
        XCTAssertEqual(error!.domain, GRMustacheErrorDomain)
        XCTAssertEqual(error!.code, GRMustacheErrorCodeRenderingError)
        
        template = try! Template(string:"<{{replace(missing(name))}}>")
        do {
            rendering = try template.render(box)
        } catch var error1 as NSError {
            error = error1
            rendering = nil
        }
        XCTAssertNil(rendering)
        XCTAssertEqual(error!.domain, GRMustacheErrorDomain)
        XCTAssertEqual(error!.code, GRMustacheErrorCodeRenderingError)
        
        template = try! Template(string:"<{{missing(replace(name))}}>")
        do {
            rendering = try template.render(box)
        } catch var error1 as NSError {
            error = error1
            rendering = nil
        }
        XCTAssertNil(rendering)
        XCTAssertEqual(error!.domain, GRMustacheErrorDomain)
        XCTAssertEqual(error!.code, GRMustacheErrorCodeRenderingError)
    }
    
    func testNotAFilterError() {
        let box = Box([
            "name": "Name",
            "filter": "filter"
            ])
        
        var template = try! Template(string:"<{{filter(name)}}>")
        var error: NSError?
        var rendering: String?
        do {
            rendering = try template.render(box)
        } catch var error1 as NSError {
            error = error1
            rendering = nil
        }
        XCTAssertNil(rendering)
        XCTAssertEqual(error!.domain, GRMustacheErrorDomain)
        XCTAssertEqual(error!.code, GRMustacheErrorCodeRenderingError)
    }
    
    // TODO: port this test to Objective-C GRMustache
    func testMissingFilterErrorDescriptionContainsLineNumber() {
        let template = try! Template(string: "\n{{f(x)}}")
        var error: NSError?
        let rendering: String?
        do {
            rendering = try template.render(error: &error)
        } catch _ {
            rendering = nil
        }
        XCTAssertNil(rendering)
        XCTAssertEqual(error!.domain, GRMustacheErrorDomain)
        XCTAssertEqual(error!.code, GRMustacheErrorCodeRenderingError)
        XCTAssertTrue(error!.localizedDescription.rangeOfString("Missing filter") != nil)
        XCTAssertTrue(error!.localizedDescription.rangeOfString("line 2") != nil)
    }
    
    // TODO: port this test to Objective-C GRMustache
    func testMissingFilterErrorDescriptionContainsTemplatePath() {
        // TODO
    }
    
    // TODO: port this test to Objective-C GRMustache
    func testNotAFilterErrorDescriptionContainsLineNumber() {
        let template = try! Template(string: "\n{{f(x)}}")
        var error: NSError?
        let rendering: String?
        do {
            rendering = try template.render(Box(["f": "foo"]))
        } catch var error1 as NSError {
            error = error1
            rendering = nil
        }
        XCTAssertNil(rendering)
        XCTAssertEqual(error!.domain, GRMustacheErrorDomain)
        XCTAssertEqual(error!.code, GRMustacheErrorCodeRenderingError)
        XCTAssertTrue(error!.localizedDescription.rangeOfString("Not a filter") != nil)
        XCTAssertTrue(error!.localizedDescription.rangeOfString("line 2") != nil)
    }
    
    // TODO: port this test to Objective-C GRMustache
    func testNotAFilterErrorDescriptionContainsTemplatePath() {
        // TODO
    }
    
    func testFilterOfOptionalInt() {
        let square = Filter { (x: Int?, error: NSErrorPointer) in
            if let x = x {
                return Box(x * x)
            } else {
                return Box("Nil")
            }
        }
        let template = try! Template(string: "{{square(x)}}")
        template.registerInBaseContext("square", Box(square))
        
        var rendering: String?
        do {
            rendering = try template.render(Box(["x": 10]))
        } catch _ {
            rendering = nil
        }
        XCTAssertEqual(rendering!, "100")
        
        do {
            rendering = try template.render(Box())
        } catch _ {
            rendering = nil
        }
        XCTAssertEqual(rendering!, "Nil")
        
        do {
            rendering = try template.render(Box(["x": NSNull()]))
        } catch _ {
            rendering = nil
        }
        XCTAssertEqual(rendering!, "Nil")
        
        do {
            rendering = try template.render(Box(["x": "foo"]))
        } catch _ {
            rendering = nil
        }
        XCTAssertEqual(rendering!, "Nil")
    }
    
    func testFilterOfOptionalString() {
        let twice = Filter { (x: String?, error: NSErrorPointer) in
            if let x = x {
                return Box(x + x)
            } else {
                return Box("Nil")
            }
        }
        let template = try! Template(string: "{{twice(x)}}")
        template.registerInBaseContext("twice", Box(twice))
        
        var rendering: String?
        do {
            rendering = try template.render(Box(["x": "A"]))
        } catch _ {
            rendering = nil
        }
        XCTAssertEqual(rendering!, "AA")
        
        do {
            rendering = try template.render(Box(["x": "A" as NSString]))
        } catch _ {
            rendering = nil
        }
        XCTAssertEqual(rendering!, "AA")
        
        do {
            rendering = try template.render(Box())
        } catch _ {
            rendering = nil
        }
        XCTAssertEqual(rendering!, "Nil")
        
        do {
            rendering = try template.render(Box(["x": NSNull()]))
        } catch _ {
            rendering = nil
        }
        XCTAssertEqual(rendering!, "Nil")
        
        do {
            rendering = try template.render(Box(["x": 1]))
        } catch _ {
            rendering = nil
        }
        XCTAssertEqual(rendering!, "Nil")
    }
    
    // TODO: import ValueTests.testCustomValueFilter(): testFilterOfOptionalXXX, testFilterOfXXX, etc. for all supported types
}
