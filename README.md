# Welcome to Helix!
## Before You Begin...
### What is Helix?
  Helix is an interpreted imperative programming language, currently in its beta. Right now, Helix is written in Swift, but in later versions, Helix will be rewritten in Rust. Helix focuses on the idea that errors should not be because of implicit coercions or guessing. Helix uses an experimental paradigm called COP (copy-oriented programming). More about them later.
  ___

### How do you Use Helix?
  Currently, Helix is Apple-only. However, check back to when Helix is on its third major version to see if the Rust rewrite has happened. If it did, great! You can run it. If not, the rewrite should be around the corner after all the major features have been secured.
  ___

### What Promises Does Helix Make?
  Helix is designed to eliminate entire classes of implicit logic bugs. For example, code like `"5" + 2` (JavaScript) will _not_ run. Another example is this:
```
short s = 30000;
int i = 30000;
short sum = s + i;
```
(C++)
While Helix does not have a `short` type, Helix will make sure that there are minimal implicit bugs in your code.
In short, Helix guarantees _semantic explicitness_, but not correctness.
___

### What Are Some Promises Helix Can't Make?
  Helix does **not** fix explicit logic bugs. Examples like `let x = 2 + 1; // make sure this is 4`, or `if (x == 5) { // remember x is always 4` pass through Helix's runtime safely and are not flagged, but are still bugs.

Another thing Helix can't promise is performance. Helix is planned to be written in Rust, and eventually be executed in bytecode to VM style, but for now, the AST is directly evaluated.
___
## Actually Programming in Helix

### Printing
In Helix, printing is very simple; it's just `print()`. Fair warning though, this function-like print will be deprecated soon (version 2 or 3) and be replaced with a more complex syntax: `@Io => print()`, once the multi-file feature is implemented.
Some examples are:
```
print("Hello, World!") // prints "Hello, World!"
print("My name is Bob") // prints "My name is Bob"
```

`print()` also allows variables and expressions; just put in the variable (or expression) between the parenthesis, and it'll print its contents:
```
print(2 + 3) // prints 5
```
___

### Defining Variables
  Like any other language, defining a variable is just `var`. With one important caveat- to ensure semantic correctness, you _need_ to specify the variable's type. If you **really** don't want to specify the type and want the interpreter to infer the type, then use the `some` keyword, but it is generally advised not to use this.
___

### What Types Are There?
  Helix has 7 primitive types- 4 type values (`string`, `number`, `boolean`, `void`), and 3 type wrappers (`array`, `optional`, `pointer`).
  
**string**
Represents text. There is no `character` type.

**number**
Represents a floating-point number. Integers are not included in the primitive types because you can represent integers as floored numbers.

**boolean**
Represents a value that can either be `true` or `false`. Nothing can convert to a boolean, but a boolean can be converted to other types.

**void**
Represents 'no value'. It is purely used for function, and _should not_ be used for variables.

**array(type)**
Represents a collection of `type` , i.e. `array(number)` means a collection of numbers.

**optional(type)**
Represents that the type (or more accurately, the value) can be `null` (no value). Note that `null(type)` is **not** the same as void.
**IMPORTANT**: `null` is not an "all type" null. Its type needs to be specified, so if you have a variable whose type is `optional(number)` and you want to show that it has no value, the correct syntax is: `null(number)`

**pointer(type)**
Represents a reference to a value with type **type**. If you had `&num`, that can be fed into a variable declaration with type `pointer(number)`. So basically, `&num` gives

**Types These Primitives can Represent**
- character
- integer

### Defining Constants
  Similarly for variables, constants are defined with `let`. All the rules of defining variable also apply here, however, you cannot change the value.
___

### Operators
| Operator | Description |
|----------|-------------|
| `+` | adds two values |
|`-`|subtracts two values|
|`*`|multiplies two values|
|`/`|divides two values|
|`->`| creates an inclusive numeric range (used primarily in for-loops) |
|`==`|compares if two values are equal|
|`!=`|compares if two values are not equal|
|`>`|compares if the first number is greater than the second|
|`<`|compares if the first number is less than the second|
|`>=`|compares if the first number is greater than or equal to the second|
|`<=`|compares if the first number is less than or equal to the second|
|`!`|returns the opposite of a boolean value, so !false returns true, and !true returns false|
|`&`|makes a reference to a variable, not a value|
|`*`|if marked before a variable, it dereferences the variable (e.g., if x was a pointer to y that held 2, then *x returns 2)|

### Modifying Variables
  When running programs, generally, you want to modify data. To do that, simply put the variable name (say, x), along with '='. After that, just put whatever you want as long as it is the type the variable was originally created as (so no putting a number value to a variable that accepts string).
___

### Control Flow
Control flow is split into 3 sub-sections: if statements, for statements, and while statements.

#### Branching Statements
  If statements are defined when you put the `if` keyword. The expression after the `if` is what determines which part of the if statement runs.
  Example Code:
  ```
  let x: number = 5
  if x > 0 { // runs
    print("x is bigger than 0")
  }
  ```
  Brackets don't always have to be inline. They can have as many newlines as you want, but there must be **no** expressions in those whitespace.
If you want code to run if the condition is false, put the `else` keyword after the } (or a set amount of newlines after }, and as explained, **no** expressions in the whitespace). For example, in our example code, the if part always runs (because 5 > 0), but if x was -1, nothing would run because there is no `else` keyword after }. However, if we modify our code to be:
```
let x: number = -1
if x > 0 {
  print("x is bigger than 0")
} else {
  print("x is less than or equal to 0")
}
```
The else body would run, which means it would print "x is less than or equal to 0".
___

#### For Statements
  For statements loop a piece of code a set amount of times, whether that be looping through the elements of an array, or going through a range. You start a for statement by starting with `for`. There is only **one** valid format for for statements; `for name1, name2, name3, ... in collection1, collection2, collection3, ... {`. And yes, the same bracket rule applies to {. For example, here's a for loop that counts from 1 to 4:
```
for i in 1 -> 4 {
  print(i)
}

Output:
1
2
3
4
```
For loops can also loop through arrays by binding their elements to the name every iteration:
```
for elem in ["hello", "goodbye", "world"] {
  print(elem)
}

Output:
hello
goodbye
world
```
**IMPORTANT**: for loops terminate at the second the shortest array or range ends
Here's an example combining them two and create what's known as an enumerated array, or a 'multi-binding loop' in Helix:
```
let primes: array(number) = [2, 5, 7, 11]
for index, element in 0 -> (length(primes) - 1), primes { // we'll learn about length later, just know it gives you the length of the array
  print("index ", index, ": ", element)
}

Output:
index 0: 2
index 1: 5
index 2: 7
index 3: 11
```
___

#### While Statements
  While statements are like for loops, but instead of running in a set amount of iterations, a while loop keeps repeating a piece of code **while** the condition is true.
So if you had something like x > 5, as its expression, then it would keep repeating the same code until x was below or equal to 5. Here's an example of that in motion:
```
var x: number = 0
while x != 5 {
  print(x)
  x = x + 1
}

Output:
1
2
3
4
```
You can see how when x reaches 5, it doesn't print 5.
**IMPORTANT**: an infinite loop is when a loop (most likely while) doesn't terminate and keep running code. i.e.:
```
var x: number = 0
while x != 5 {
  print(x)
  // no x = x + 1
}

Output:
0
0
0
0
0
0
0
0
0
0
...
```
This will cause a memory leak, and maybe crash the program and very likely, app. Use infinite loops carefully; I'll add `break` and `continue` in the next minor version.
___

### Function Definition
  Functions are reusable pieces of code that you can pass and call around. Functions take in a parameter (sometimes none), and return a type. As mentioned before in **What Types are There?**, `void` is used to signify that a function does not return any value. However, you still need to specify that you are returning `void`.

  Functions are declared in this format:
  `fn name(p1: type1, p2: type2, p3: type3, ...) => return_type {`. Now, you can use `name` anywhere you want. Note that when you use `name`, you need to plug in its parameters.
Here's a example that greets the user:
```
fn greet(name: string) => void {
  print("Hello, ", name, "!")
}

greet("Bob")

Output:
Hello, Bob!
```
  If you're returning a non-void function, then you'd need to plug that call into an expression. Say if you have `some_number()`, and its definition says it returns a number, you'd generally use it like `some_number() + 1`. 
___

## Conclusion
  It's been a very fun time writing this language, and I'd love it if you'd give feedback and bugs. Thank you for reading the documentary, and have a good day!
