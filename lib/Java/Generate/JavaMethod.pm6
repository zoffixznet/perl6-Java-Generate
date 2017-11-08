use Java::Generate::Expression;
use Java::Generate::Variable;
use Java::Generate::Statement;
use Java::Generate::ASTNode;
use Java::Generate::JavaSignature;
use Java::Generate::Statement;
use Java::Generate::Utils;

unit module Java::Generate::JavaMethod;

role JavaMethod does ASTNode is export {
    has Str $.name;
    has JavaSignature $.signature;
}

class InterfaceMethod does JavaMethod is export {
    has AccessLevel $.access;
    has Str $.return-type;

    method generate(--> Str) {
        "{$!access} {$!return-type} {$!name}();"
    }
}

class ConstructorMethod does JavaMethod is export {
    has Statement @.statements;

    method generate(--> Str) {
        my $code = "{$!name}({$!signature.generate()}) \{";
        $code ~= "{@!statements.map(*.generate()).join.indent(4)}" if @!statements;
        $code ~= "\}";
    }
}

class ClassMethod does JavaMethod is export {
    has AccessLevel $.access;
    has Statement @.statements;
    has Modifier @.modifiers;
    has Str $.return-type;

    method generate(Variable :%vars --> Str) {
        my $code = "{$!access}";
        $code ~= ' ' ~ @!modifiers.join(' ') if @!modifiers;
        $code ~= " {$!return-type} {$!name}({$!signature.generate()}) \{\n";
        $code ~= @!statements.map(
            {
                if $_ ~~ VariableDeclaration {
                    # Local
                    my $var = .variable;
                    die "Variable {.variable.name} already declared" if %vars{$var.name};
                    %vars{$var.name} = .variable;
                    %vars{$var.name}.initialized = True if $var.default;
                } elsif $_ ~~ Expression {
                    # Expression
                    %vars{.left.name}.initialized = True if $_ ~~ Assignment;
                    for .operands {
                        die "Variable 「$_」 is not declared"     unless %vars{$_};
                        die "Variable 「$_」 is not initialized!" unless %vars{$_}.initialized;
                    }
                }
                my $c = .generate();
                $c.ends-with(';') ?? $c !! $c ~ ';'
            }).join("\n").indent(4) if @!statements;
        $code ~= "\n\}\n";
    }
}
