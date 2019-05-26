.PHONY: all clean

languages = Haskell Haskell2 OCaml Rust Rust_parallel \
	    C++98 C++11 C++14 C++14_boost C++17 C CSharp D D_parallel Go Go_goroutine Vala \
	    Nim NodeJS NodeJS_async NodeJS_cluster CoffeeScript CoffeeScript_parallel \
	    Java Chicken Racket FreePascal Erlang CommonLisp_opt \
	    Dart ChezScheme Scala Cython

all: $(languages)

.PHONY: $(languages)
$(languages): %:
	$(MAKE) -C $*

clean:
	for d in $(languages); do $(MAKE) clean -C "$$d"; done

maketime: clean
	> $@
	for d in $(languages); do time -f "%e $$d" -a -o $@ $(MAKE) -C "$$d"; done
	sort $@ -o $@  -t" " -k1 -n
	cat $@
