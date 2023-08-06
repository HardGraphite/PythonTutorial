# 装饰器 (Decorators)

## 什么是装饰器

概括地说，
装饰器装饰了函数定义语句（FunctionDef）和类定义（ClassDef）语句，
是一个**用来对函数或类进行转换的函数**。

下面是几个简单的例子：

```python
@decorator1
def some_func():
    ...

@decorator2
class some_class:
    @decorator3
    def some_method():
        ...
```

其中，
`decorator1`、 `decorator2` 和 `decorator3` 是装饰器，
`some_func`、 `some_class` 和 `some_method` 是被装饰的语法结构。

## 装饰器是如何工作的

要解释装饰器如何工作，
首先需要了解函数和类在运行期间是如何被“定义”的。
借助内置模块 `dis`，我们可以查看 CPython 的字节码。
以函数定义语句为例：

```python
import dis

src = '''
def some_func():
    ...
'''

dis.dis(compile(src, '', 'exec'))
```

得到以下输出：

```
  0           0 RESUME                   0

  2           2 LOAD_CONST               0 (<code object some_func at 0x7f6b76341d70, file "", line 2>)
              4 MAKE_FUNCTION            0
              6 STORE_NAME               0 (some_func)
              8 LOAD_CONST               1 (None)
             10 RETURN_VALUE

Disassembly of <code object some_func at 0x7f6b76341d70, file "", line 2>:
  2           0 RESUME                   0

  3           2 LOAD_CONST               0 (None)
              4 RETURN_VALUE
```

> 接触过汇编或其它平台字节码的朋友应该能轻松理解上面的输出。
> 否则，请参考相应文档（参见文末“参考”一节中关于“dis”的链接）辅助理解。

可以看到，在顶层创建一个函数分为以下几步：

1. 取出函数对应的 `code` 对象（即函数体对应的字节码）
2. 按照此对象创建新的函数对象
3. 取出函数的名称（一个字符串）
4. 将新创建的函数对象保存为此名称所指示的全局变量

以上步骤可以表示为这样的伪代码：

```python
# 1.
code = __get_code_object_at__(0x7f6b76341d70)
# 2.
func = __make_function_from_code__(code)
# 3.
name = 'some_func'
# 4.
setattr(name, func)

# or ...

setattr('some_func', __make_func_at__(0x7f6b76341d70))
```

可以看到，创建函数（1和2）和保存为变量（3和4）是分开的两步。
前面提到，装饰器其实是一个转换器。
把创建的函数输入“转换器”，再将“转换器”的输出保存为变量，这就实现了对函数的转换，即装饰。
用伪代码表示为：

```python
# 1.
code = __get_code_object_at__(0x7f6b76341d70)
# 2.
func = __make_function_from_code__(code)
# new step here
func = decorator(func)
# 3.
name = 'some_func'
# 4.
setattr(name, func)

# or ...

setattr('some_func', decorator(__make_func_at__(0x7f6b76341d70)))
```

来看一下使用转换器后的字节码长什么样：

```python
import dis

src = '''
@decorator
def some_func():
    ...
'''

dis.dis(compile(src, '', 'exec'))
```

输出为：

```
  0           0 RESUME                   0

  2           2 LOAD_NAME                0 (decorator)

  3           4 LOAD_CONST               0 (<code object some_func at 0x7f6b76342c70, file "", line 2>)
              6 MAKE_FUNCTION            0

  2           8 PRECALL                  0
             12 CALL                     0

  3          22 STORE_NAME               1 (some_func)
             24 LOAD_CONST               1 (None)
             26 RETURN_VALUE

Disassembly of <code object some_func at 0x7f6b76342c70, file "", line 2>:
  2           0 RESUME                   0

  4           2 LOAD_CONST               0 (None)
              4 RETURN_VALUE
```

与预期完全一致。

## 如何编写装饰器

前面提到，装饰器就是一个转换器。
还是以函数的装饰器为例，它应当接受一个函数作为参数，并返回一个函数。
这部分用一些例子来展示如何编写装饰器。

### 基本的装饰器

下面这个装饰器 `time_func` 可以在函数执行前后打印信息
（函数 `repr_func_args` 与装饰器的教学无关，故独立出来，以便理解）：

```python
def repr_func_args(args, kwargs) -> str:
    args_repr = ', '.join(repr(a) for a in args)
    kwargs_repr = ', '.join(f'{k!r}={v!r}' for k, v in kwargs.items())
    if args_repr:
        if kwargs:
            return args_repr + ', ' + kwargs_repr
        else:
            return args_repr
    else:
        return kwargs_repr

def time_func(func):
    """A decorator to print calls to a function."""
    def _wrapper(*args, **kwargs):
        name = func.__name__
        print(f'Calling {name}({repr_func_args(args, kwargs)}) ...')
        ret_val = func(*args, **kwargs)
        print(f'{name} returned {ret_val}')
        return ret_val
    return _wrapper
```

来试一下：

```python
@time_func
def my_add(lhs, rhs):
    return lhs + rhs

@time_func
def my_mul(lhs, rhs):
    return lhs * rhs

my_add(1, 2)
my_mul(3.14, 2.71)
```

输出为：

```
Calling my_add(1, 2) ...
my_add returned 3
Calling my_mul(3.14, 2.71) ...
my_mul returned 8.5094
```

如果你无法理解这里发生了什么，
可以参照前文对装饰器的伪代码表示：

> ```python
> setattr('some_func', decorator(__make_func_at__(0x7f6b76341d70)))
> ```

在这里，我们将具体内容填进去，就是：

```python
# @time_func
# def my_add(lhs, rhs):
#     return lhs + rhs

#   |
#   V

def my_add(lhs, rhs):
    return lhs + rhs

my_add = time_func(my_add)
```

即，首先定义了函数原本的样子，再应用装饰器，把函数进行转换，用将结果覆盖原先的定义。

### 带有参数的装饰器

有时，可能需要一个带参数的修饰器。
一个简单的实现方法是：定义一个用来构造装饰器的函数，将对这个函数的调用作为装饰器。

下面这个装饰器实现了这样的效果：
判断当前操作系统是否为给定的值；若是，则保留原始函数；若不是，则将函数转换为空的函数。

```python
import platform

def enable_on_os(name: str):
    """Enable function on the specified OS."""
    if name == platform.system():
        return lambda f: f
    else:
        def _empty_func(*args, **kwargs):
            raise NotImplementedError()
        return lambda f: _empty_func
```

来试一下：

```python
@enable_on_os('Linux')
def code_for_linux():
    print('Hello, Linux!')

@enable_on_os('Windows')
def code_for_windows():
    print('Hello, Windows!')

@enable_on_os('Darwin')
def code_for_darwin():
    print('Hello, macOS!')

try:
    code_for_linux()
    code_for_windows()
    code_for_darwin()
except:
    pass
```

不同平台会得到不同的结果。
我在 Linux 上运行，
得到以下结果：

```
Hello, Linux!
```

如果你无法理解这里发生了什么，
可以参照上一部分对简单装饰器的展开：

> ```python
> # @time_func
> # def my_add(lhs, rhs):
> #     return lhs + rhs
>
> #   |
> #   V
>
> def my_add(lhs, rhs):
>     return lhs + rhs
>
> my_add = time_func(my_add)
> ```

本部分的装饰器变成了一个函数调用，
故展开后也是一个函数调用，但实际上形式没有变：

```python
# @enable_on_os('Linux')
# def code_for_linux():
#     print('Hello, Linux!')
#

#  |
#  V

def code_for_linux():
    print('Hello, Linux!')

code_for_linux = enable_on_os('Linux')(code_for_linux)
```

如果你仍然没有理解，可以将调用过程分开写：

```python
def code_for_linux():
    print('Hello, Linux!')

decorator = enable_on_os('Linux')
code_for_linux = decorator(code_for_linux)
```

这样，形式就与上部分的简单装饰器的展开完全一样了。

### 可调用对象作为装饰器

从 CPython 生成的字节码可以看出，
作为装饰器的对象不一定非要是函数不可。
任何可调用对象都可以用于装饰器。

下面的例子用装饰器实现了对特定函数的收集：

```python
class FunctionCollection:
    def __init__(self):
        self.functions = []

    def __repr__(self) -> str:
        return f'<{type(self).__name__} {self.functions}>'

    def __call__(self, f):
        # Here is why it can be a decorator.
        self.functions.append(f)
        return f
```

来试一下：

```python
the_functions = FunctionCollection()

@the_functions
def foo():
    ...

@the_functions
def bar():
    ...

print(the_functions)
```

运行代码，得到以下结果：

```
<FunctionCollection [<function foo at 0x7f6b760f2fc0>, <function bar at 0x7f6b760f3060>]>
```

相信你一定能理解其中的原理了吧！

### 其它

前面只涉及了函数的装饰器。
实际上，应用于方法和类的装饰器的原理是一样的。

可以阅读装饰器 `dataclasses.dataclass` 的源码了解类的装饰器的实现。
*(选择这个例子，只是因为下文会展示其用法。)*

## 内置的装饰器

Python builtin 和标准库提供了不少装饰器。
熟悉它们可以帮助你更容易地写出简洁可读的代码。
阅读它们的实现也能让你学习如何写出复杂却可靠的装饰器。
[这个网页](https://wiki.python.org/moin/Decorators)
列举了 Python 提供的各种装饰器。

下面是一些使用内置装饰器的例子：

```python
import dataclasses

@dataclasses.dataclass
class Coord:
    x: float
    y: float

    @staticmethod
    def origin() -> 'Coord':
        return Coord(0, 0)

class Point:
    COORD_X_MIN = -100
    COORD_X_MAX = +100
    COORD_Y_MIN = -50
    COORD_Y_MAX = +50

    def __init__(self, coord: Coord):
        self.coord = coord

    def __repr__(self) -> str:
        pos = self.coord
        return f'<{type(self).__name__} ({pos.x},{pos.y})>'

    @property
    def coord(self) -> Coord:
        return self._coord

    @coord.setter
    def coord(self, value: Coord):
        if not (
            Point.COORD_X_MIN <= value.x <= Point.COORD_X_MAX and
            Point.COORD_Y_MIN <= value.y <= Point.COORD_Y_MAX
        ):
            raise ValueError('coordinates out of bounds')
        self._coord = value

p1 = Point(Coord.origin())
p1.coord = Coord(x=3, y=4)
print(p1)
try:
    p1.coord = Coord(1000, 100000)
except ValueError as e:
    print('Error:', e)
```

## 参考

1. [PEP 318 – Decorators for Functions and Methods](https://peps.python.org/pep-0318/)
2. [PEP 3129 – Class Decorators](https://peps.python.org/pep-3129/)
3. [ast - Abstract Syntax Trees / Abstract Grammar](https://docs.python.org/3/library/ast.html#abstract-grammar)
4. [dis - Disassembler for Python bytecode](https://docs.python.org/3/library/dis.html)
5. [Decorators](https://wiki.python.org/moin/Decorators)
