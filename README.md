[![Actions Status](https://github.com/raku-community-modules/Data-StaticTable/actions/workflows/linux.yml/badge.svg)](https://github.com/raku-community-modules/Data-StaticTable/actions) [![Actions Status](https://github.com/raku-community-modules/Data-StaticTable/actions/workflows/macos.yml/badge.svg)](https://github.com/raku-community-modules/Data-StaticTable/actions) [![Actions Status](https://github.com/raku-community-modules/Data-StaticTable/actions/workflows/windows.yml/badge.svg)](https://github.com/raku-community-modules/Data-StaticTable/actions)

NAME
====

Data::StaticTable - a static memory structure in Raku

INTRODUCTION
============

A StaticTable allows you to handle bidimensional data in a more natural way

Some features:

  * Rows starts at 1 (`Data::StaticTable::Position` is the datatype used to reference row numbers)

  * Columns have header names

  * Any column can work as an index

If the number of elements provided does not suffice to form a square or a rectangle, filler cells will be added as filler (you can define what goes in these filler cells as well).

The module provides two classes: `StaticTable` and `StaticTable::Query`.

A StaticTable can be populated, but it can not be modified later. To perform searchs and create/store indexes, a Query object is provided. You can add indexes per column, and perform searches (grep) later. If an index exists, it will be used.

You can get data by rows, columns, and create subsets by taking some rows from an existing StaticTable.

TYPES
=====

Data::StaticTable::Position
---------------------------

Basically, an integer greater than 0. Used to indicate a row position in the table. A StaticTable do not have rows on index 0.

OPERATORS
=========

eqv
---

Compares the contents (header and data) of two StaticTable objects. Returns `False` as soon as any difference is detected, and `True` if it finds that everything is equal.

```raku
say '$t1 and $t2 are ' ~ ($t1 eqv $t2) ?? 'equal' !! 'different';
```

Data::StaticTable CLASS
=======================

Positional features
-------------------

### Brackets []

You can use [n] to get the full Nth row, in the way of a hash of **'Column name'** => data

So, for example

```raku
$t[1]
```

Could return a hash like

```raku
{Column1 => 10, Column2 => 200.4, Column3 => 450}
```

And a call like

```raku
$t[10]<Column3>
```

would refer to the data in Row 10, with the heading Column3

### The `ci` hash

On construction, a public hash called `ci` (short for **c**olumn **i**ndex) is created. If for some reason, you need to refer the columns by number instead of name, this hash contains the column numbers as keys, and the heading name as values.

if your column number **2** has the name "Weight", you can read the cell in the third row of that column like this:

```raku
my $val1 = $t.cell('Weight', 3);
my $val2 = $t[3]<Weight>;
```

Or by using the `ci` hash

```raku
my $val1 = $t.cell($t.ci<2>, 3);
my $val2 = $t[3]{$t.ci<2>};
```

method new
----------

Depending on how your source data is organized, you can use the 2 **flat array** constructors or a **rowset** constructor.

**Flat array** allows you to pass a long one dimensional array and order it in rows and columns, by specifiying a header. You can pass an array of string to specify the column names, or just a number of columns if you don't care about the column names.

**Rowset** works when your data is already bidimensional, and it can include a first row as header. In the case that your rows contains a hash, you can tell the constructor, and it will take the hash keys to create a header with the appropiate column names. In this case, any row that does not contain a hash will be discarded (you have the option to recover the discarded data).

### The flat array constructor

```raku
my $t1 = StaticTable.new( 3 , (1 .. 15) );
my $t2 = StaticTable.new(
  <Column1 Column2 Column3> ,
  (
  1, 2, 3,
  4, 5, 6,
  7, 8, 9,
  10,11,12
  13,14,15
  )
);
```

This will create a spreadsheet-like table, with numbered rows and labeled columns.

In the case of `$t1`, since the first parameter is a number, it will have columns named automatically, as `A`, `B`, `C`... etc.

`$t2` has an array as the first parameter. So it will have three columns labeled `Column1`, `Column2` and `Column3`.

You just need to provide an array to fill the table. The rows and columns will be automatically cut and filled in a number of rows.

If you do not provide enough data to fill the last row, empty cells will be appended.

If you already have your data ordered in an array of arrays, use the rowset constructor described below.

### The rowset constructor

You can also create a StaticTable from an array, with each element representing a row. The StaticTable will acommodate the values as best as possible, adding empty values or discarding values that go beyond the boundaries, or data that is not prepared appropiately

This constructor can be called like this, using an Array of Arrays

```raku
my $t = StaticTable.new(
  (1,2,3),
  (4,5,6),
  (7,8,9)
);
```

For a Array of Hashes, you can call it like this

```raku
my $t = StaticTable.new(
 [
  { name => 'Eggplant', color => 'aubergine', type => 'vegetal' },
  { name => 'Egg', color => ('white', 'beige'), type => 'animal' },
  { name => 'Banana', color => 'yellow', type => 'fruit' },
  { name => 'Avocado', color => 'green', type => 'fruit',  class => 'Hass' }
 ]
);
```

*(Note the use of brackets, we needed to explicitly pass an Array of Hashes)*

There is a set of named parameters usable in this constructor

```raku
my $t = StaticTable.new(@ArrayOfArrays):data-has-header
```

This will use the first row as header. Any value that falls outside the column boundaries determined by the header will be discarded in each row.

```raku
my $t = StaticTable.new(@ArrayOfHashes):set-of-hashes
```

This will consider each row as a hash, and will create columns for each key found. The most populated will be the first columns. Any row that is not a hash will be discarded

### Recovering discarded data

In some situations, some data can be rejected from your original array passed to the constructor. This will happen in two cases, using the rowset constructor:

  * You specified `:data-has-header` but there are rows longer that the length of the header. So, if your first row had 4 elements, any row with more that 4 elements will be cut and the extra elements will be rejected

  * You specified `:set-of-hashes` but there are rows that does not contain hashes. All these rows will be rejected too.

For recovering discarded data from an Array of Arrays:

```raku
my %rejected;
my $tAoA = StaticTable.new(
  @ArrayOfArrays, rejected-data => %rejected # <--- Note, rejected is a hash
):data-has-header
```

In this case, `%rejected` is a hash where the key is the row from where the data was discarded, pointing to an array of the elements discarded in that row.

For recovering discarded data from an Array of Hashes:

```raku
my @rejected;
my $tAoH = StaticTable.new(
  @ArrayOfHashes, rejected-data => @rejected # <--- rejected is an array
):set-of-hashes
```

In this case, `@rejected` will have a list of all the rejected rows.

### The `filler` value

There is another named parameter, called `filler`. This is used to complete rows that need more cells, so the table has every row with the same number of elements.

By default, it uses `Nil`.

Example:

```raku
my $t = Data::StaticTable.new(
  <A B C>,
  (1,2,3,
   4,5,6,
   7),     # 2 last cells will be fillers, so the 3rd row is complete
  filler => 'N/A'
);

print $t[3]<C>; #This will print N/A
```

method raku
-----------

Returns a representation of the StaticTable. Can be used for serialization.

method clone
------------

Returns a newly created StaticTable with the same attributes. It does **not** copy attributes to clone. Instead, runs the constructor again.

method display
--------------

Shows a 'visual' representation of the contents of the StaticTable. Used for debugging, **not for serialization**.

It would look like this:

    A   B   C
    ⋯  ⋯  ⋯
    [1] [2] [3]
    [4] [5] [6]
    [7] [8] [9]

However, you could save the output of this method to a tab-separated csv file.

method cell(Str $column-heading, Position $row)
-----------------------------------------------

Retrieves the content of a cell.

method column(Str $column-heading)
----------------------------------

Retrieves the content of a column like a regular `List`.

method row(Position $row)
-------------------------

Retrieves the content of a row as a regular `List`.

method shaped-array
-------------------

Retrieves the content of the table as a multiple dimension array.

method elems
------------

Retrieves the number of cells in the table

method generate-index(Str $heading)
-----------------------------------

Generate a `Hash`, where the key is the value of the cell, and the value is a list of row numbers (of type `Data::StaticTable::Position`).

method take(@rownums where .all ~~ Position)
--------------------------------------------

Generate a new `StaticTable`, using a list of row numbers (using the type `Data::StaticTable::Position`)

The order of the rows will be kept, and you can consider repeated rows. You can use `.unique` and `.sort` on the row numbers list. A sorted, unique list will make the construction of the new table **faster**. Consider this is you want to use a lot of rownums.

```raku
#-- Order and repeated rows will be kept
my $new-t1 = $t.take(@list);
#-- Consider this if @list is big, not sorted and has repeated elements
my $new-t2 = $t.take(@list.uniq.sort)

=end raku

You can combine this with C<generate-index>

=begin code :lang<raku>

my %i-Status = $t.generate-index("Status");
# We want a new table with rows where Status = "Open"
my $t-open = $t.take(%i-Status<Open>);
# We want another where Status = "Awaiting feedback"
my $t-waiting = $t.take(%i-Status{'Awaiting feedback'});
```

Also works with the `.grep` method from the `StaticTable::Query` object. This allows to you do more complex searches in the columns.

An identical, but slurpy version of this method is also available for convenience.

Data::StaticTable::Query CLASS
==============================

Since StaticTable is immutable, a helper class to perform searches is provided. It can contain generated indexes. If an index is provided, it will be used whenever a search is performed.

Associative features
--------------------

You can use hash-like keys, to get a specific index for a column

```raku
$Q1<Column1>
$Q1{'Column1'}
```

Both can get you the index (the same you could get by using `generate-index` in a `StaticTable`).

method new(Data::StaticTable $T, *@to-index)
--------------------------------------------

You need to specify an existing `StaticTable` to create this object. Optionally you can pass a list with all the column names you want to consider as indexes.

Examples:

```raku
my $q1 = Data::StaticTable::Query.new($t);            #-- No index at construction
my $q2 = Data::StaticTable::Query.new($t, 'Address'); #-- Indexing column 'Address'
my $q3 = Data::StaticTable::Query.new($t, $t.header); #-- Indexing all columns
```

If you don't pass any column names in the constructor, you can always use the method `add-index` later

method raku
-----------

Returns a representation of the StaticTable::Query object. Can be used for serialization.

**Note:** This value will contain *the complete* StaticTable for this index.

method keys
-----------

Returns the name of the columns indexed.

method values
-------------

Returns the values indexed.

method k
--------

Returns the hash of the same indexes in the `Query` object.

method grep(Mu $matcher where { -> Regex {}($_); True }, Str $heading, Bool :$h = True, Bool :$n = False, Bool :$r = False, Bool :$nr = False, Bool :$nh = False)
-----------------------------------------------------------------------------------------------------------------------------------------------------------------

Allows to use grep over a column. Depending on the flags used, returns the resulting row information for all that rows where there are matches. You can not only use a regxep, but a `Junction` of `Regex` elements.

Examples of Regexp and Junctions:

```raku
# Get the rownumbers where the column 'A' contains '9'
my Data::StaticTable::Position @rs1 = $q.grep(rx/9/, "A"):n;
# Get the rownumbers where the column 'A' contains 'n' and 'e'
my Data::StaticTable::Position @rs2 = $q.grep(all(rx/n/, rx/e/), "A"):n;
```

When you use the flag `:n`, you can use these results later with the method `take`

### Flags

Similar to the default grep method, this contains flags that allows you to receive the information in various ways.

Consider this StaticTable and its Query:

```raku
my $t = Data::StaticTable.new(
  <Countries  Import      Tons>,
  (
    'US PE CL', 'Copper',    100, # Row 1
    'US RU',    'Alcohol',   50,  # Row 2
    'IL UK',    'Processor', 12,  # Row 3
    'UK',       'Tuxedo',    1,   # Row 4
    'JP CN',    'Tuna',      10,  # Row 5
    'US RU CN', 'Uranium',   0.01 # Row 6
  )
);
my $q = Data::StaticTable::Query.new($t)
```

  * :n

Returns only the row numbers.

This is very useful to combine with the `take` method.

```raku
my @a = $q.grep(all(rx/US/, rx/RU/), 'Countries'):n;
# Result: The array (2, 6)
```

  * :r

Returns the rows, just data, no headers

```raku
my @a = $q.grep(all(rx/US/, rx/RU/), 'Countries'):r;
# Result: The array
# [
#       ("US RU", "Alcohol", 50),
#       ("US RU CN", "Uranium", 0.01)
# ]
```

  * :h

Returns the rows as a hash with header information

This is the default mode. You don't need to use the `:h` flag to get this result

```raku
my @a1 = $q.grep(all(rx/US/, rx/RU/), 'Countries'):h; # :h is the default
my @a2 = $q.grep(all(rx/US/, rx/RU/), 'Countries');   # @a1 and @a2 are identical
# Result: The array
# [
#      {:Countries("US RU"), :Import("Alcohol"), :Tons(50)},
#      {:Countries("US RU CN"), :Import("Uranium"), :Tons(0.01)}
# ]
```

  * :nr

Like `:r` but in a hash, with the row number as the key

```raku
my %h = $q.grep(all(rx/US/, rx/RU/), 'Countries'):nr;
# Result: The hash
# {
#    "2" => $("US RU", "Alcohol", 50),
#    "6" => $("US RU CN", "Uranium", 0.01)
# }
```

  * :nh

Like `:h` but in a hash, with the row number as the key

```raku
my %h = $q.grep(all(rx/US/, rx/RU/), 'Countries'):nh;
# Result: The hash
# {
#    "2" => ${:Countries("US RU"), :Import("Alcohol"), :Tons(50)},
#    "6" => ${:Countries("US RU CN"), :Import("Uranium"), :Tons(0.01)}
# }
```

method add-index($column-heading)
---------------------------------

Creates a new index, and it will return a score indicating the index quality. Values of 1, or very close to zero are the less ideals.

Nevertheless, even an index with a score 1 will help.

Example:

```raku
my $q1 = Data::StaticTable::Query.new($t); #-- Creates index and ...
$q1.add-index('Address');                  #-- indexes the column 'Address'
```

When an index is created, it is used automatically in any further `grep` calls.

AUTHOR
======

shinobi

COPYRIGHT AND LICENSE
=====================

Copyright 2018 - 2019 shinobi

Copyright 2024 Raku Community

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

