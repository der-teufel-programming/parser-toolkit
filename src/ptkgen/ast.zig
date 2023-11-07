const std = @import("std");
const ptk = @import("parser-toolkit");

const Location = ptk.Location;

pub fn List(comptime T: type) type {
    return struct {
        pub const Item = T;

        pub const Node = std.TailQueue(T).Node;

        inner: std.TailQueue(T) = .{},

        pub fn append(list: *@This(), item: *@This().Node) void {
            list.inner.append(item);
        }

        pub fn len(list: @This()) usize {
            return list.inner.len;
        }

        pub fn only(list: @This()) ?T {
            return if (list.inner.len == 1)
                list.inner.first.?.data
            else
                null;
        }
    };
}

pub fn Iterator(comptime T: type) type {
    return struct {
        node: ?*List(T).Node,

        pub fn next(iter: *@This()) ?*T {
            const current = iter.node orelse return null;
            iter.node = current.next;
            return &current.data;
        }
    };
}

pub fn iterate(list: anytype) Iterator(@TypeOf(list).Item) {
    return Iterator(@TypeOf(list).Item){ .node = list.inner.first };
}

pub fn Reference(comptime T: type) type {
    return struct {
        pub const Referenced = T;

        location: Location,
        identifier: ptk.strings.String,
    };
}

fn String(comptime Tag: anytype) type {
    return struct {
        pub const tag = Tag;

        location: Location,
        value: ptk.strings.String,
    };
}

pub const Identifier = String(.identifier);
pub const StringLiteral = String(.string);
pub const CodeLiteral = String(.code);
pub const UserDefinedIdentifier = String(.user_defined);

pub const Document = List(TopLevelDeclaration);

pub const TopLevelDeclaration = union(enum) {
    start: RuleRef,
    rule: Rule,
    node: Node,
    pattern: Pattern,
};

pub const NodeRef = Reference(Node); // !mynode
pub const RuleRef = Reference(Rule); // <myrule>
pub const PatternRef = Reference(Pattern); // $mytoken

pub const ValueRef = struct { // $0
    location: Location,
    index: u32,
};

pub const Node = struct { // node <name> = ...;
    name: Identifier,
    value: TypeSpec,
};

pub const Rule = struct { // rule <name> ( : <type> )? = ...;
    name: Identifier, //
    ast_type: ?TypeSpec, // if specified, defines the ast node of the rule
    productions: List(MappedProduction), // all alternatives of the rule
};

pub const Pattern = struct { // token <name> = ...;
    name: Identifier,
    pattern: Data,

    pub const Data = union(enum) {
        literal: StringLiteral, // literal "+"
        word: StringLiteral, // word "while"
        regex: StringLiteral, // regex "string"
        external: CodeLiteral, // custom `matchMe`
    };
};

pub const MappedProduction = struct { // ... => value
    production: Production, // the thing before "=>"
    mapping: ?AstMapping, // the thing after "=>"
};

pub const Production = union(enum) {
    literal: StringLiteral, // "text"
    terminal: PatternRef, // $token
    recursion: RuleRef, // <rule>
    sequence: List(Production), // ...
    optional: List(Production), // ( ... )?
    repetition_zero: List(Production), // [ ... ]*
    repetition_one: List(Production), // [ ... ]+
};

pub const AstMapping = union(enum) {
    record: List(FieldAssignment), // { field = ..., field = ... }
    list: List(AstMapping), // { ..., ..., ... }
    variant: VariantInitializer, // field: ...

    literal: CodeLiteral, // field: value
    context_reference: ValueRef, // $0
    user_reference: UserDefinedIdentifier, // @field
    user_function_call: FunctionCall(UserDefinedIdentifier), // @builtin(a,b,c)
    function_call: FunctionCall(Identifier), // identifier(a,b,c)
};

pub const VariantInitializer = struct {
    field: Identifier,
    value: *AstMapping,
};

pub fn FunctionCall(comptime Name: type) type {
    return struct {
        function: Name,
        arguments: List(AstMapping),
    };
}

pub const FieldAssignment = struct {
    location: Location,
    field: Identifier,
    value: *AstMapping,
};

pub const TypeSpec = union(enum) {
    reference: NodeRef, // !type
    literal: CodeLiteral, // literal `bool`
    custom: UserDefinedIdentifier, // custom `Custom`
    record: CompoundType, // struct <fields...>
    variant: CompoundType, // union <fields...>
};

pub const CompoundType = struct {
    location: Location,
    fields: List(Field),
};

pub const Field = struct {
    location: Location,
    name: Identifier,
    type: TypeSpec,
};
