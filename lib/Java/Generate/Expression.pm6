use Java::Generate::Variable;
use Java::Generate::Literal;
use Java::Generate::Argument;
use Java::Generate::Statement;

unit module Java::Generate::Expression;

role Expression does Java::Generate::Statement::Statement is export {
    method operands() {()}
}

class ConstructorCall does Expression is export {
    has Str $.name;
    has Argument @.arguments;

    method generate(--> Str) {
        "new {$!name}({@!arguments.map(*.generate).join(', ')})";
    }
}

class MethodCall does Expression is export {
    has Variable $.object;
    has Str $.name;
    has Argument @.arguments;

    method generate(--> Str) {
        "{$!object.reference()}.{$!name}({@!arguments.map(*.generate).join(', ')});";
    }

    method operands() {
        $!object ~~ LocalVariable ?? ($!object.name) !! ()
    }
}

my subset Operand where Variable|Literal|Expression;

class PrefixOp does Expression is export {
    my subset Op of Str where '++'|'--'|'+'|'-'|'~'|'!';
    has Operand $.right;
    has Op $.op;

    method generate() {
        my $right = $_ ~~ Variable ?? .reference() !! .generate() given $!right;
        $right = "($right)" if $!right ~~ Expression;
        "{$!op}$right"
    }

    method operands() {
        return ($!right.name) if $!right ~~ LocalVariable;
        return $!right.operands if $!right ~~ Expression;
        ()
    }
}

class PostfixOp does Expression is export {
    my subset Op of Str where '++'|'--';
    has Operand $.left;
    has Op $.op;

    method generate() {
        my $left = $_ ~~ Variable ?? .reference() !! .generate() given $!left;
        $left = "($left)" if $!left ~~ Expression;
        "{$left}{$!op}"
    }

    method operands() {
        return ($!left.name) if $!left ~~ LocalVariable;
        return $!left.operands if $!left ~~ Expression;
        ()
    }
}

class Assignment does Expression is export {
    has Variable $.left;
    has Operand $.right;

    method generate(--> Str) {
        my $right = $_ ~~ Variable ?? .reference() !! .generate() given $!right;
        "{$!left.reference()} = $right"
    }

    method operands() {
        my $right;
        $right = ($!right.name) if $!right ~~ LocalVariable;
        $right.append: $!right.operands if $!right ~~ Expression;
        my $operands;
        $operands.append: $!left.name if $!left ~~ LocalVariable;
        $operands.append: $right if $right;
        $operands.flat
    }
}

class InfixOp does Expression is export {
    my subset Op of Str where '+'|'-'|'*'|'/'|'%'|
                              '<<'|'>>'|'>>>'|
                              '&'|'^'|'|'|
                              '<'|'>'|'=='|'!='||'&&'|'||';

    has Operand $.left;
    has Operand $.right;
    has Op $.op;

    method generate(--> Str) {
        my $left  = $_ ~~ Variable ?? .reference() !! .generate() given $!left;
        my $right = $_ ~~ Variable ?? .reference() !! .generate() given $!right;
        $left  = "($left)"  if $!left  ~~ Expression;
        $right = "($right)" if $!right ~~ Expression;
        "$left {$!op} $right"
    }

    method operands() {
        my @operands;
        for ($!left, $!right) {
            @operands.append: .name     if $_ ~~ LocalVariable;
            @operands.append: .operands if $_ ~~ Expression;
        }
        @operands.flat
    }
}

class Ternary does Expression is export {
    has InfixOp $.cond;
    has Operand $.true;
    has Operand $.false;

    method generate(--> Str) {
        unless $!cond.op eq '<'|'>'|'=='|'!='|'&&'|'||' {
            die "Ternary operator condition expression is not boolean, it\'s operator is {$!cond.op}";
        }

        my $true  = $_ ~~ Variable ?? .reference() !! .generate() given $!true;
        my $false = $_ ~~ Variable ?? .reference() !! .generate() given $!false;
        "{$!cond.generate} ? $true : $false"
    }

    method operands() {
        my @operands;
        for ($!true, $!false) {
            @operands.append: .name     if $_ ~~ LocalVariable;
            @operands.append: .operands if $_ ~~ Expression;
        }
        @operands.flat
    }
}

