use Java::Generate::Class;
use Java::Generate::Expression;
use Java::Generate::JavaMethod;
use Java::Generate::JavaSignature;
use Java::Generate::Literal;
use Java::Generate::Statement;
use Java::Generate::Variable;
use Test;

plan 7;

my (@statements, $method);

my $code = q:to/END/;
public void foo() {
    final int a;
    int b = 5;
    double c;
    b++;
}
END

my $signature = JavaSignature.new(:parameters());
my $variable = LocalVariable.new(:name<a>, :modifiers<final>, :type<int>);
@statements = VariableDeclaration.new($variable),
              VariableDeclaration.new('b', 'int', (), IntLiteral.new(5, 'dec')),
              VariableDeclaration.new('c', 'double', ()),
              PostfixOp.new(left => LocalVariable.new(:name<b>), :op<++>);
$method = ClassMethod.new(:access<public>, :name<foo>,
                          :$signature, :return-type<void>,
                          :@statements);

is $method.generate, $code, 'Method with declarations is generated';

# No initialized variable usage dies
@statements = VariableDeclaration.new('a', 'int', ()),
              InfixOp.new(left => LocalVariable.new(:name<a>), right => IntLiteral.new(5, 'dec') :op<+>);
$method = ClassMethod.new(:access<public>, :name<bar>,
                          :$signature, :return-type<void>,
                          :@statements);

dies-ok { $method.generate }, 'Cannot use non-initialized local variable';

# Double initialization dies
@statements = VariableDeclaration.new('a', 'int', (), IntLiteral.new(5, 'dec')),
              PostfixOp.new(left => LocalVariable.new(:name<a>), :op<++>),
              VariableDeclaration.new('a', 'int', ());
$method = ClassMethod.new(:access<public>, :name<bar>,
                          :$signature, :return-type<void>,
                          :@statements);
dies-ok { $method.generate }, 'Cannot initialize local variable twice';

# Usage of undeclared variable dies
@statements = PostfixOp.new(left => LocalVariable.new(:name<a>), :op<++>);
$method = ClassMethod.new(:access<public>, :name<bar>,
                          :$signature, :return-type<void>,
                          :@statements);
dies-ok { $method.generate }, 'Cannot use undeclared local variable';

# Usage of instance fields is ok
@statements = PostfixOp.new(left => InstanceVariable.new(:name<a>), :op<++>);
$method = ClassMethod.new(:access<public>, :name<bar>,
                          :$signature, :return-type<void>,
                          :@statements);
my $class = Class.new(
    :access<public>,
    :name<A>,
    methods => $method,
    fields => InstanceVariable.new(:access<public>, :name<a>, :type<int>)
);

lives-ok { $class.generate }, 'Method knows about class fields';

# Assignment to undeclared variable dies
@statements = Assignment.new(
    left  => LocalVariable.new(:name<a>),
    right => InfixOp.new(
        left  => IntLiteral.new(5, 'dec'),
        right => IntLiteral.new(9, 'hex')
    )
);
$method = ClassMethod.new(:access<public>, :name<bar>,
                          :$signature, :return-type<void>,
                          :@statements);
dies-ok { $method.generate }, 'Assignment to undeclared variable dies';

# Assignment to undeclared variable dies
@statements = VariableDeclaration.new('a', 'int', ()),
              Assignment.new(
                  left  => LocalVariable.new(:name<a>),
                  right => InfixOp.new(
                      left  => IntLiteral.new(5, 'dec'),
                      right => IntLiteral.new(9, 'hex'),
                      op => '*'
                  )
              );
$method = ClassMethod.new(:access<public>, :name<bar>,
                          :$signature, :return-type<void>,
                          :@statements);
lives-ok { $method.generate }, 'Assignment to declared variable lives';