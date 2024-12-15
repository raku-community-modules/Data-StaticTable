use X::Data::StaticTable;
unit module Data;

subset StaticTable::Position of Int where * >= 1;

class StaticTable {
    has Position $.columns;
    has Position $.rows;
    has @!data;
    has Str @.header;
    has %.ci; #-- Gets the heading (Str) for a column number (Position)
    has $!filler;

    method raku {
        my @all-cells;
        for 1 .. $.rows -> $i { push @all-cells, |self.row($i); }
        
       'Data::StaticTable.new('
         ~ @.header.raku ~ ', '
         ~ @all-cells.raku ~ ')'
    }

    method display {
        my Str $out;
        for 1 .. $!rows -> $row-num {
            $out ~= "\n";
            for 1 .. $!columns -> $col-num {
                my $cell = self!cell-by-position($col-num, $row-num).raku;
                $out ~= "[" ~ $cell ~ "]\t";
            }
        }
        my Str $header;
        $header = join("\t", @.header);
        my Str @u;
        for @.header -> $h {
            @u.append("⋯" x $h.chars);
        }
        $header ~ "\n" ~ join("\t", @u) ~ $out;
    }

    submethod BUILD (
    :@!data, :@!header, :%!ci, Position :$!columns, Position :$!rows
    ) { }
    method !calculate-dimensions(Position $columns, Int $elems, $filler) {
        my $extra-cells = $elems % $columns;
        $extra-cells = $columns - $extra-cells if ($extra-cells > 0);
        my @additional-cells = $filler xx $extra-cells; #'Nil' objects to fill an incomplete row, will appear as 'Any'
        my Position $rows = ($elems + $extra-cells) div $columns;
        $rows, |@additional-cells
    }

    multi method new(@header!, +@new-data, :$filler = Nil) {
        if @header.elems < 1 {
            X::Data::StaticTable.new("Header is empty").throw;
        }
        if @new-data.elems < 1 {
            X::Data::StaticTable.new("No data available").throw;
        }
        my ($rows, @additional-cells) = self!calculate-dimensions(@header.elems, @new-data.elems, $filler);
        my Int $col-num = 1;
        my %column-index = ();
        for @header -> $heading { %column-index{$heading} = $col-num++; }
        if @header.elems != %column-index.keys.elems {
            X::Data::StaticTable.new("Header has repeated elements").throw;
        };

        @new-data.append(@additional-cells);
        self.bless(
            columns => @header.elems,
            rows    => $rows,
            data    => @new-data,
            header  => @header.map(*.Str),
            ci      => %column-index
        )
    }
    multi method new(Position $columns!, +@new-data, :$filler = Nil) {
        my @header = ('A', 'B' ... *)[0 ... $columns - 1].list;
        self.new(@header, @new-data);
    }

    #== Rowset constructor: just receive an array and do our best to handle it ==
    multi method new(@new-data,         #-- By default, @new-data is an array of arrays
        Bool :$set-of-hashes = False,   #-- Receiving an array with hashes in each element
        Bool :$data-has-header = False, #-- Asume an array of arrays. First row is the header
        :$rejected-data is raw = Nil,   #-- Rejected rows or cells will be returned here
        :$filler = Nil
    ) {
        if $set-of-hashes && $data-has-header {
            X::Data::StaticTable.new("Contradictory flags using the 'rowset' constructor").throw;
        }
        my (@data, @xeno-hash, %xeno-array); #-- @xeno will be used ONLY if rejected-rows is provided
        my @header;

        #-----------------------------------------------------------------------
        if ($set-of-hashes) { #--- HASH MODE -----------------------------------
            # Pass 1: Weed out not-hashes and determine an optimal header
            my %column-frequency;
            my @hashable-data;
            for @new-data -> $row-ref {
                if $row-ref ~~ Hash { # Sort Columns so most common ones appear at first
                    my %row = %$row-ref;
                    for %row.keys { %column-frequency{$_}++ }
                    push @hashable-data, $row-ref;
                } else {
                    push @xeno-hash, $row-ref if $rejected-data.defined;
                }
            }
            if @hashable-data.elems == 0 {
                X::Data::StaticTable.new("No data available").throw;
            }
            @header = %column-frequency.sort({ -.value, .key }).map: (*.keys[0]);
            # Pass 2: Populate with data
            for @hashable-data -> $hash-ref {
                my %row = %$hash-ref;
                for @header -> $heading {
                    push @data, (%row{$heading}.defined) ?? %row{$heading} !! $filler;#?
                }
            }
            @$rejected-data = @xeno-hash if $rejected-data.defined;
        } else { #--- ARRAY MODE -----------------------------------------------
            my Data::StaticTable::Position $columns;
            my $first-data-row = 0;
            if $data-has-header {
                @header = @new-data[0];
                @header = @header>>[].flat; #-- Completely flatten the header
                $columns = @header.elems;
                $first-data-row = 1;
            } else {
                $columns = @new-data.max(*.elems).elems;
                @header = ('A', 'B' ... *)[0 ... $columns - 1].list;
            }
            my $i = 1;
            for @new-data[$first-data-row ... *] -> $row-ref {
                my @row = @$row-ref;
                %xeno-array{$i} = @row.splice($columns) if (@row.elems > $columns);
                push @row, |($filler xx $columns - @row.elems) if @row.elems < $columns;
                push @data, |@row;
                $i++;
            }
            %$rejected-data = %xeno-array if $rejected-data.defined;
        } #---------------------------------------------------------------------
        self.new(@header, @data)
    }

    #-- Accessing cells directly
    method !cell-by-position(Position $col!, Position $row!) {
        my $pos = ($!columns * ($row-1)) + $col - 1;
        if $pos < @!data.elems { return @!data[$pos]; }
        X::Data::StaticTable.new("Out of bounds").throw;
    }
    method cell(Str $column-header, Position $row) {
        my Position $column-number = self!column-number($column-header);
        self!cell-by-position($column-number, $row)
    }

    #-- Retrieving a column by its name
    method !column-number(Str $heading) {
        if %!ci{$heading}:exists { return %!ci{$heading}; }
        X::Data::StaticTable.new("Heading $heading not found").throw;
    }

    method column(Str $heading) {
        my Position $column-number = self!column-number($heading);
        my Int $pos = $column-number - 1;
        @!data[$pos+($!columns*0), $pos+($!columns*1) ... *]
    }

    #-- Retrieving specific rows
    method row(Position $row) {
        if $row < 1 || $row > $.rows {
            X::Data::StaticTable.new("Out of bounds").throw;
        }
        @!data[($row-1) * $!columns ... $row * $!columns - 1]
    }
    method !rows(@rownums) {
        my @result = gather for @rownums -> $num { take self.row($num) };
        @result
    }

    #-- Shaped arrays
    #-- Raku shaped arrays:  @a[3;2] <= 3 rows and 2 columns, starts from 0
    #-- This method returns the data only (not headers)
    method shaped-array() {
        my @shaped;
        my @rows = self!rows(1 .. $.rows);
        for 1 .. $.rows -> $r {
            my @row = @rows[$r];
            for 1 .. $.columns -> $c {
                @shaped[$r - 1;$c - 1] = self!cell-by-position($c, $r);
            }
        }
        @shaped
    }

    #==== Positional =====
    multi method elems(::?CLASS:D:) {
        @!data.elems
    }

    method AT-POS(::?CLASS:D: Position $row) {
        return @.header.list if ($row == 0);
        my @row = self.row($row);
        my %full-row;
        for 0 .. $.columns - 1 -> $i {
            %full-row{@.header[$i]} = @row[$i];
        }
        %full-row
    }

    #==== Index ====
    method generate-index(Str $heading) {
        my %index;
        my Position $row-num = 1;
        my @full-column = self.column($heading);
        for @full-column -> $item {
            if $item.defined {
                if %index{$item}:!exists {
                    my Position @a = ();
                    %index{$item} = @a;
                }
                push %index{$item}, $row-num++;
            }
        }
        %index
    }

    #--- Returns raw data cells from a set of rows
    #--- Any repeated row is ignored (recovers only one)
    method !gather-rowlist(@rownums) {
        if @rownums.elems == 0 {
            X::Data::StaticTable.new("No data available").throw;
        }
        #-- If we are receiving the output from generate-index, it might be
        #-- possible that elements of @rownums are also arrays
        @rownums = @rownums>>[].flat;
        if any(@rownums) > $.rows {
            X::Data::StaticTable.new("No data available").throw;
        }
        my @result = ();
        if @rownums.elems == 1 {
            @result = self.row(@rownums[0])
        } else {
            #--- Instead of getting row by row, we
            #--- get whole blocks of continous rows.
            my @block;
            my @rowsets;
            @rownums.rotor(2 => -1).map: -> ($a,$b) {
                push @block, $a;
                if ($a+1 != $b) {
                    @rowsets.push( $(@block.clone) );
                    @block = ();
                };
                LAST {
                	push @block, $b;
                	@rowsets.push( $(@block.clone) );
                }
            };
            #-- TODO: get a little bit more speed? We only need the min and
            #-- max of each block when populating above, hence avoiding to use
            #-- .min and .max functions below
            for @rowsets -> $block-num {
                my $min-row = $block-num.min;
                my $max-row = $block-num.max;
                my $start = ($!columns * ($min-row - 1)); #1st element of the first row
                my $end = ($!columns * ($max-row - 1)) + $!columns - 1; #last element of the last row
                @result.append(@!data[$start ... $end]);
            }
        }
        @result
    }

    multi method take(@rownums where .all ~~ Position) {
        self.new(@!header, self!gather-rowlist(@rownums))
    }
    multi method take(*@rownums where .all ~~ Position) {
        self.take(@rownums)
    }

    method clone() {
        self.new(@.header, @!data, filler => $!filler)
    }
}

#------------------------------------------------------------------------------#
#------------------------------------------------------------------------------#

class StaticTable::Query {
    has %!indexes handles <keys elems values kv AT-KEY EXISTS-KEY>;
    has Data::StaticTable $!T is built;

    method raku {
        my @indexes = %!indexes.keys;
        my $out = 'Data::StaticTable::Query.new(' ~ $!T.raku;
        $out ~=  ", " ~ @indexes.raku if (@indexes.elems > 0);
        $out ~= ")";
        $out
    }

    multi method new(Data::StaticTable $T, *@to-index) {
        my $q = self.bless(T => $T);
        return $q if (@to-index.elems == 0);
        for @to-index -> $heading {
            $q.add-index($heading);
        }
        $q
    }

    method grep(Mu $matcher where { -> Regex {}($_); True }, Str $heading,
        Bool :$n = False,  # Row numbers
        Bool :$r = False,  # Array of array
        Bool :$h = False,   # Array of hashes (Default)
        Bool :$nr = False, # Row numbers => row data (array)
        Bool :$nh = False, # Row numbers => row data (hash)
    ) {
        my $default = $h;
        $default = True if all($n, $r, $h, $nr, $nh) == False;
        X::Data::StaticTable.new("Method grep only accepts one adverb at a time").throw unless one($n, $r, $default, $nr, $nh) == True;
        my Data::StaticTable::Position @rownums;
        if %!indexes{$heading}:exists { #-- Search in the index if it is available. Should be faster.
            my @keysearch = grep {.defined and $_ ~~ $matcher}, %!indexes{$heading}.keys;
            for @keysearch -> $k {
                @rownums.push(|%!indexes{$heading}{$k});
            }
        } else {
            @rownums = 1 <<+>> ( grep {.defined and $_ ~~ $matcher}, :k, $!T.column($heading) );
        }
        if $n { # Returning rowlist
            @rownums.sort.list                           #-- :n
        }
        elsif $r || $default { # Returning an array of arrays or array of hashes
            my @rows;
            for @rownums.sort -> $row-num {
                if ($r) { push @rows, $!T.row($row-num) } #-- :r
                else    { push @rows, $!T[$row-num]     } #-- :h
            }
            @rows
        }
        else { # A hash of row-num => data in the row or row-num => a row hash
            my %hash;
            for @rownums.sort -> $row-num {
                if $nh { %hash{$row-num} = $!T[$row-num]     } #-- :nh
                else   { %hash{$row-num} = $!T.row($row-num) } #-- :nr
            }
            %hash
        }
    }

    #==== Index ====
    method add-index(Str $heading) {
        my %index;
        my Data::StaticTable::Position $row-num = 1;
        my @full-column = $!T.column($heading);
        for @full-column -> $item {
            if $item.defined {
                if %index{$item}:!exists {
                    my Data::StaticTable::Position @a = ();
                    %index{$item} = @a;
                }
                push %index{$item}, $row-num++;
            }
        }
        %!indexes{$heading} = %index;
        my $score = (%index.keys.elems / @full-column.elems).Rat;
        $score
    }
}

multi sub infix:<eqv>(StaticTable $t1, StaticTable $t2 --> Bool) {
    return False if !($t1.header eqv $t2.header);
    for $t1.header.race -> $heading {
        return False unless $t1.column($heading) eqv $t2.column($heading);
    }
    True
}

# vim: expandtab shiftwidth=4
