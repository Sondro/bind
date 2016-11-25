package bind.objc;

using StringTools;

typedef BindContext = {
    var objcClass:bind.Class;
    var indent:Int;
    var files:Array<bind.File>;
    var namespace:String;
    var pack:String;
    var currentFile:bind.File;
}

class Bind {

    public static function createContext():BindContext {

        return {
            objcClass: null,
            indent: 0,
            files: [],
            namespace: null,
            pack: null,
            currentFile: null,
        };

    } //createContext

    /** Reads bind.Class object informations and generate files
        To bind the related Objective-C class to Haxe.
        The files are returned as an array of bind.File objects.
        Nothing is written to disk at this stage. */
    public static function bindClass(objcClass:bind.Class, ?options:{?namespace:String, ?pack:String}):Array<bind.File> {

        trace(bind.Json.stringify(objcClass, true));

        var ctx = createContext();
        ctx.objcClass = objcClass;

        if (options != null) {
            if (options.namespace != null) ctx.namespace = options.namespace;
            if (options.pack != null) ctx.pack = options.pack;
        }

        // Generate Objective C++ file
        generateObjCPPFile(ctx);

        // Generate Haxe file
        generateHaxeFile(ctx);

        return ctx.files;

    } //bindClass

    public static function generateObjCPPFile(ctx:BindContext, header:Bool = false):Void {

        ctx.currentFile = { path: 'bind_' + ctx.objcClass.name + '.mm', content: '' };

        writeLine('#import "hxcpp.h"', ctx);
        writeLine('#import <Foundation/Foundation.h>', ctx);

        writeLineBreak(ctx);

        var namespaceEntries = [];
        if (ctx.namespace != null && ctx.namespace.trim() != '') {
            namespaceEntries = ctx.namespace.split('::');
        }

        // Class comment
        if (ctx.objcClass.description != null && ctx.objcClass.description.trim() != '') {
            writeComment(ctx.objcClass.description, ctx);
            if (namespaceEntries.length == 0) {
                writeLineBreak(ctx);
            }
        }

        // Open namespaces
        for (name in namespaceEntries) {
            writeLine('namespace $name {', ctx);
            ctx.indent++;
            writeLineBreak(ctx);
        }

        // Add methods
        for (method in ctx.objcClass.methods) {

            // Constructor?
            var isObjcConstructor = isObjcConstructor(method, ctx);

            // Method return type
            var ret = toHxcppType(method.type, ctx);

            // Method name
            var name = method.name;

            var args = [];

            // Instance handle as first argument
            if (method.instance && !isObjcConstructor) {
                args.push('::Dynamic instance_');
            }

            // Method args
            for (arg in method.args) {
                args.push(toHxcppType(arg.type, ctx) + ' ' + arg.name);
            }

            // Method comment
            if (method.description != null && method.description.trim() != '') {
                writeComment(method.description, ctx);
            }

            // Whole method
            writeIndent(ctx);
            write(ret + ' ' + ctx.objcClass.name + '_' + name + '(' + args.join(', ') + ')', ctx);
            if (header) {
                write(';', ctx);
            }
            else {
                write(' {', ctx);
                writeLineBreak(ctx);
                ctx.indent++;

                // Method body
                //
                // Convert args to Objc
                var toObjc = [];
                var i = 0;
                for (arg in method.args) {
                    writeObjcArgAssign(arg, i, ctx);
                    i++;
                }
                // Call Objc
                writeObjcCall(method, ctx);

                ctx.indent--;
                writeIndent(ctx);
                write('}', ctx);
            }
            writeLineBreak(ctx);
            writeLineBreak(ctx);

        }

        // Close namespaces
        for (name in namespaceEntries) {
            ctx.indent--;
            writeLine('}', ctx);
            writeLineBreak(ctx);
        }

        ctx.files.push(ctx.currentFile);
        ctx.currentFile = null;

    } //generateObjCPPFile

    public static function generateHaxeFile(ctx:BindContext, header:Bool = false):Void {

        var reserved = ['new', 'with'];

        var dir = '';
        if (ctx.pack != null && ctx.pack.trim() != '') {
            dir = ctx.pack.replace('.', '/') + '/';
        }

        ctx.currentFile = { path: dir + ctx.objcClass.name + '.hx', content: '' };

        var packPrefix = '';
        if (ctx.pack != null && ctx.pack.trim() != '') {
            packPrefix = ctx.pack.trim() + '.';
            writeLine('package ' + ctx.pack.trim() + ';', ctx);
        } else {
            writeLine('package;', ctx);
        }

        writeLineBreak(ctx);

        // Class comment
        if (ctx.objcClass.description != null && ctx.objcClass.description.trim() != '') {
            writeComment(ctx.objcClass.description, ctx);
        }

        writeLine('class ' + ctx.objcClass.name + ' {', ctx);
        ctx.indent++;
        writeLineBreak(ctx);

        writeLine('private var _instance:Dynamic = null;', ctx);
        writeLineBreak(ctx);

        writeLine('public function new() {}', ctx);
        writeLineBreak(ctx);

        writeLine('public function destroy() {', ctx);
        ctx.indent++;
        writeLine('_instance = null;', ctx);
        ctx.indent--;
        writeLine('}', ctx);
        writeLineBreak(ctx);

        // Add methods
        for (method in ctx.objcClass.methods) {

            // Constructor?
            var isObjcConstructor = isObjcConstructor(method, ctx);

            // Method return type
            var ret = toHaxeType(method.type, ctx);

            // Method name
            var name = method.name;
            if (reserved.indexOf(name) != -1) {
                name = '_' + name;
            }

            var args = [];

            // Method args
            for (arg in method.args) {
                args.push(arg.name + ':' + toHaxeType(arg.type, ctx));
            }

            // Method comment
            if (method.description != null && method.description.trim() != '') {
                writeComment(method.description, ctx);
            }

            writeIndent(ctx);

            // Static method?
            if (!method.instance) {
                write('static ', ctx);
            }

            // Whole method
            write('function ' + name + '(' + args.join(', ') + '):', ctx);
            if (isObjcConstructor) {
                write(ctx.objcClass.name, ctx);
            } else {
                write(ret, ctx);
            }
            write(' {', ctx);
            writeLineBreak(ctx);
            ctx.indent++;

            writeIndent(ctx);
            if (isObjcConstructor) {
                write('_instance = ', ctx);
            } else {
                switch (method.type) {
                    case Void(orig):
                    default:
                        write('return ', ctx);
                }
            }
            write(ctx.objcClass.name + '_Extern.' + name + '(', ctx);
            var i = 0;
            if (!isObjcConstructor && method.instance) {
                write('_instance', ctx);
                i++;
            }
            for (arg in method.args) {
                if (i > 0) write(', ', ctx);
                write(arg.name, ctx);
                i++;
            }
            write(');', ctx);
            writeLineBreak(ctx);
            if (isObjcConstructor) {
                writeLine('return this;', ctx);
            }

            ctx.indent--;
            writeLine('}', ctx);

            writeLineBreak(ctx);

        }

        ctx.indent--;
        writeLine('}', ctx);
        writeLineBreak(ctx);

        // Extern class declaration
        writeLine('@:keep', ctx);
        writeLine('@:include(\'bind_' + ctx.objcClass.name + '.h\')', ctx);
        writeLine('#if (!display && !lint)', ctx);
        writeLine('@:build(bind.Linc.touch())', ctx);
        writeLine('@:build(bind.Linc.xml(\'' + ctx.objcClass.name + '\', \'./\'))', ctx);
        writeLine('#end', ctx);
        writeLine('@:allow(' + packPrefix + ctx.objcClass.name + ')', ctx);
        writeLine('private extern class ' + ctx.objcClass.name + '_Extern {', ctx);
        ctx.indent++;
        writeLineBreak(ctx);

        // Add methods
        for (method in ctx.objcClass.methods) {

            // Constructor?
            var isObjcConstructor = isObjcConstructor(method, ctx);

            // Method return type
            var ret = toHaxeType(method.type, ctx);

            // Method name
            var name = method.name;
            if (reserved.indexOf(name) != -1) {
                name = '_' + name;
            }

            var args = [];

            // Instance argument
            if (method.instance && !isObjcConstructor) {
                args.push('instance_:Dynamic');
            }

            // Method args
            for (arg in method.args) {
                args.push(arg.name + ':' + toHaxeType(arg.type, ctx));
            }

            // C++ method
            writeIndent(ctx);
            write('@:native(\'', ctx);
            if (ctx.namespace != null && ctx.namespace.trim() != '') {
                write(ctx.namespace.trim() + '::', ctx);
            }
            write(ctx.objcClass.name + '_' + method.name, ctx);
            write('\')', ctx);
            writeLineBreak(ctx);

            writeIndent(ctx);

            // Whole method
            write('static function ' + name + '(' + args.join(', ') + '):' + ret, ctx);
            write(';', ctx);

            writeLineBreak(ctx);
            writeLineBreak(ctx);

        }

        // Class end
        ctx.indent--;
        writeLine('}', ctx);
        writeLineBreak(ctx);

        ctx.files.push(ctx.currentFile);
        ctx.currentFile = null;

    } //generateHaxeFile

    static function isObjcConstructor(method:bind.Class.Method, ctx:BindContext):Bool {

        var isObjcConstructor = false;
        var objcType = toObjcType(method.type, ctx);
        if (method.instance && method.name.startsWith('init') && (objcType == 'instancetype' || objcType == ctx.objcClass.name + '*')) {
            isObjcConstructor = true;
        }

        return isObjcConstructor;

    } //isObjcConstructor

/// Objective-C -> Haxe

    static function toHaxeType(type:bind.Class.Type, ctx:BindContext):String {

        var result = switch (type) {
            case Void(orig): 'Void';
            case Int(orig): 'Int';
            case Float(orig): 'Float';
            case Bool(orig): 'Bool';
            case String(orig): 'String';
            case Array(orig): 'Array<Dynamic>';
            case Map(orig): 'Dynamic';
            case Object(orig): 'Dynamic';
            case Function(args, ret, orig): toHaxeFunctionType(type, ctx);
        }

        return result;

    } //toHaxeType

    static function toHaxeFunctionType(type:bind.Class.Type, ctx:BindContext):String {

        var result = 'Dynamic';

        switch (type) {
            case Function(args, ret, orig): toHaxeFunctionType(type, ctx);
            default:
        }

        return result;

    } //toHaxeFunctionType

/// Objective-C -> HXCPP

    static function toHxcppType(type:bind.Class.Type, ctx:BindContext):String {

        var result = switch (type) {
            case Void(orig): 'void';
            case Int(orig): 'int';
            case Float(orig): 'double';
            case Bool(orig): 'bool';
            case String(orig): '::String';
            case Array(orig): toHxcppArrayType(type, ctx);
            case Map(orig): toHxcppMapType(type, ctx);
            case Object(orig): toHxcppObjectType(type, ctx);
            case Function(args, ret, orig): toHxcppFunctionType(type, ctx);
        }

        return result;

    } //toHxcppType

    static function toHxcppArrayType(type:bind.Class.Type, ctx:BindContext):String {

        return '::Dynamic';

    } //toHxcppArrayType

    static function toHxcppMapType(type:bind.Class.Type, ctx:BindContext):String {

        return '::Dynamic';

    } //toHxcppMapType

    static function toHxcppObjectType(type:bind.Class.Type, ctx:BindContext):String {

        return '::Dynamic';

    } //toHxcppObjectType

    static function toHxcppFunctionType(type:bind.Class.Type, ctx:BindContext):String {

        return '::Dynamic';

    } //toHxcppFunctionType

/// HXCPP -> Objective-C

    static function toObjcType(type:bind.Class.Type, ctx:BindContext):String {

        var orig:Dynamic = null;

        switch (type) {
            case Void(orig_): orig = orig_;
            case Int(orig_): orig = orig_;
            case Float(orig_): orig = orig_;
            case Bool(orig_): orig = orig_;
            case String(orig_): orig = orig_;
            case Array(orig_): orig = orig_;
            case Map(orig_): orig = orig_;
            case Object(orig_): orig = orig_;
            case Function(args, ret, orig_): orig = orig_;
        }

        while (orig.orig != null) {
            orig = orig.orig;
        }

        return orig.type;

    } //toObjcArg

/// Write utils (specific)

    static function writeHxcppArgAssign(arg:bind.Class.Arg, index:Int, ctx:BindContext):Void {

        var type = toHxcppType(arg.type, ctx);
        var name = (arg.name != null ? arg.name : 'arg' + (index + 1)) + '_hxcpp_';
        var value = (arg.name != null ? arg.name : 'arg' + (index + 1)) + (index == -1 ? '_objc_' : '');

        switch (arg.type) {

            case Function(args, ret, orig):
                var funcType = toHxcppType(arg.type, ctx);
                writeLine(funcType + ' ' + name + ' = null(); // Not implemented, yet', ctx);

            case String(orig):
                writeIndent(ctx);
                var objcType = toObjcType(arg.type, ctx);
                switch (objcType) {
                    case 'NSString*', 'NSMutableString*':
                        write('$type $name = ::bind::objc::NSStringToHxcpp($value);', ctx);
                    case 'char*':
                        write('$type $name = ::bind::objc::CharStringToHxcpp($value);', ctx);
                    case 'const char*':
                        write('$type $name = ::bind::objc::ConstCharStringToHxcpp($value);', ctx);
                }
                writeLineBreak(ctx);

            case Int(orig):
                writeIndent(ctx);
                write('$type $name = ($type) $value;', ctx);
                writeLineBreak(ctx);

            case Float(orig):
                writeIndent(ctx);
                var objcType = toObjcType(arg.type, ctx);
                switch (objcType) {
                    case 'NSNumber*':
                        write('$type $name = ($type) ::bind::objc::ObjcIdToHxcpp($value);', ctx);
                    default:
                        write('$type $name = ($type) $value;', ctx);
                }
                writeLineBreak(ctx);

            case Bool(orig):
                writeIndent(ctx);
                write('$type $name = ($type) $value;', ctx);
                writeLineBreak(ctx);

            default:
                writeIndent(ctx);
                write('$type $name = ::bind::objc::ObjcIdToHxcpp($value);', ctx);
                writeLineBreak(ctx);
        }

    } //writeHxcppArgAssign

    static function writeObjcArgAssign(arg:bind.Class.Arg, index:Int, ctx:BindContext):Void {

        writeIndent(ctx);

        var type = toObjcType(arg.type, ctx);
        var name = (arg.name != null ? arg.name : 'arg' + (index + 1)) + '_objc_';
        var value = (arg.name != null ? arg.name : 'arg' + (index + 1)) + (index == -1 ? '_hxcpp_' : '');

        switch (arg.type) {

            case Function(args, ret, orig):
                // Keep track of haxe instance on objc side
                write('NSHaxeWrapperClass *' + name + 'wrapper_ = [[BindObjcHaxeWrapperClass alloc] init:' + arg.name + '.mPtr];', ctx);
                writeLineBreak(ctx);
                writeIndent(ctx);
                // Assign objc block from haxe function
                var blockReturnType = toObjcType(ret, ctx);
                write(blockReturnType + ' ', ctx);
                write('(^' + name + ')(', ctx);
                var i = 0;
                for (blockArg in args) {
                    if (i++ > 0) write(', ', ctx);

                    var argName = blockArg.name;
                    if (argName == null) argName = 'arg' + i;
                    write(toObjcType(blockArg.type, ctx) + ' ' + argName, ctx);
                }
                write(') = ^' + (blockReturnType != 'void' ? blockReturnType : '') + '(', ctx);
                i = 0;
                for (blockArg in args) {
                    if (i > 0) write(', ', ctx);

                    var argName = blockArg.name;
                    if (argName == null) argName = 'arg' + (i + 1);

                    write(toObjcType(blockArg.type, ctx) + ' ' + argName, ctx);

                    i++;
                }
                write(') {', ctx);
                ctx.indent++;
                writeLineBreak(ctx);

                // Convert objc args into haxe args
                i = 0;
                for (blockArg in args) {

                    var argName = blockArg.name;
                    if (argName == null) argName = 'arg' + (i + 1);
                    var hxcppName = argName + '_hxcpp_';

                    writeHxcppArgAssign(blockArg, i, ctx);

                    i++;
                }

                // Call block
                writeIndent(ctx);
                if (blockReturnType != 'void') write('return ', ctx);
                write(name + 'wrapper_->haxeObject->__run(', ctx);

                i = 0;
                for (blockArg in args) {
                    if (i > 0) write(', ', ctx);

                    var argName = blockArg.name;
                    if (argName == null) argName = 'arg' + (i + 1);
                    var hxcppName = argName + '_hxcpp_';

                    write(hxcppName, ctx);

                    i++;
                }

                write(');', ctx);
                writeLineBreak(ctx);

                ctx.indent--;
                writeIndent(ctx);
                write('};', ctx);
                writeLineBreak(ctx);

            case String(orig):
                switch (type) {
                    case 'NSString*':
                        write('$type $name = ::bind::objc::HxcppToNSString($value);', ctx);
                    case 'NSMutableString*':
                        write('$type $name = ::bind::objc::HxcppToNSMutableString($value);', ctx);
                    case 'char*':
                        write('$type $name = ::bind::objc::HxcppToCharString($value);', ctx);
                    case 'const char*':
                        write('$type $name = ::bind::objc::HxcppToConstCharString($value);', ctx);
                }
                writeLineBreak(ctx);

            case Array(orig):
                switch (type) {
                    case 'NSArray*':
                        write('$type $name = ::bind::objc::HxcppToNSArray($value);', ctx);
                    case 'NSMutableArray*':
                        write('$type $name = ::bind::objc::HxcppToNSMutableArray($value);', ctx);
                }
                writeLineBreak(ctx);

            case Object(orig):
                if (type.endsWith('*')) {
                    write('$type $name = ::bind::objc::HxcppToObjcId((Dynamic)$value);', ctx);
                } else {
                    write('$type $name = ($type) $value;', ctx);
                }
                writeLineBreak(ctx);

            default:
                if (type.endsWith('*')) {
                    write('$type $name = ::bind::objc::HxcppToObjcId((Dynamic)$value);', ctx);
                } else {
                    write('$type $name = ($type) $value;', ctx);
                }
                writeLineBreak(ctx);
        }

    } //writeObjcArgAssign

    static function writeObjcCall(method:bind.Class.Method, ctx:BindContext):Void {

        var hasReturn = false;
        var hasParenClose = false;
        var isObjcConstructor = isObjcConstructor(method, ctx);

        writeIndent(ctx);
        switch (method.type) {
            case Void(orig):
            default:
                hasReturn = true;
        }
        if (hasReturn) {
            switch (method.type) {
                case Function(args, ret, orig):
                    write('id return_objc_ = ', ctx);
                default:
                    var objcType = toObjcType(method.type, ctx);
                    if (objcType == 'instancetype') objcType = ctx.objcClass.name + '*';
                    write(objcType + ' return_objc_ = ', ctx);
            }
        }
        if (isObjcConstructor) {
            write('[[' + ctx.objcClass.name + ' alloc]', ctx);
        } else if (method.instance) {
            write('[::bind::objc::HxcppToUnwrappedObjcId(instance_)', ctx);
        } else {
            write('[' + ctx.objcClass.name, ctx);
        }
        if (method.args.length > 0) {
            for (arg in method.args) {
                var nameSection = arg.orig.nameSection;
                write(' ' + nameSection + ':', ctx);
                write(arg.name + '_objc_', ctx);
            }
        } else {
            write(' ' + method.name, ctx);
        }
        write('];', ctx);
        writeLineBreak(ctx);
        if (hasReturn) {
            writeHxcppArgAssign({
                name: 'return',
                type: method.type
            }, -1, ctx);
            writeLine('return return_hxcpp_;', ctx);
        }

    } //writeObjcCall

/// Write utils (generic)

    static function writeComment(comment:String, ctx:BindContext):Void {

        writeIndent(ctx);
        write('/** ', ctx);
        var i = 0;
        var lines = comment.split("\n");
        while (i < lines.length) {

            var line = lines[i];

            if (i > 0) {
                writeLineBreak(ctx);
                write('    ', ctx);
            }

            write(line, ctx);

            i++;
        }

        write(' */', ctx);
        writeLineBreak(ctx);

    } //writeLine

    static function writeLine(line:String, ctx:BindContext):Void {

        writeIndent(ctx);
        write(line, ctx);
        writeLineBreak(ctx);

    } //writeLine

    static function writeIndent(ctx:BindContext):Void {

        var space = '';
        var i = 0;
        var indent = ctx.indent;
        while (i < indent) {
            space += '    ';
            i++;
        }

        write(space, ctx);

    } //writeIndent

    static function writeLineBreak(ctx:BindContext):Void {

        write("\n", ctx);

    } //writeLineBreak

    static function write(input:String, ctx:BindContext):Void {

        ctx.currentFile.content += input;

    } //write

} //Bind
