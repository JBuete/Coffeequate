define ["operators"], (operators) ->

	describe "Nodes", ->

		describe "representing addition", ->

			it "represent addition", ->
				add = new operators.Add("2", "3")
				expect(add.label).toBe("+")
				expect(add.toString()).toBe("(+ 2 3)")

				add = new operators.Add("2", "3", "4")
				expect(add.label).toBe("+")
				expect(add.toString()).toBe("(+ 2 3 4)")

			it "require at least two children", ->
				expect(-> new operators.Add()).toThrow(new Error("Add nodes must have at least two children."))
				expect(-> new operators.Add("")).toThrow(new Error("Add nodes must have at least two children."))

		describe "representing multiplication", ->

			it "represent multiplication", ->
				mul = new operators.Mul("2", "3")
				expect(mul.label).toBe("*")
				expect(mul.toString()).toBe("(* 2 3)")

				mul = new operators.Mul("2", "3", "4")
				expect(mul.toString()).toBe("(* 2 3 4)")

			it "require at least two children", ->
				expect(-> new operators.Mul()).toThrow(new Error("Mul nodes must have at least two children."))
				expect(-> new operators.Mul("")).toThrow(new Error("Mul nodes must have at least two children."))

		describe "representing powers", ->

			it "represent powers", ->
				pow = new operators.Pow("2", "3")
				expect(pow.label).toBe("**")
				expect(pow.toString()).toBe("(** 2 3)")

		it "can be formed into a tree", ->

			# (+ 1 (* 2 3))
			expect((new operators.Add(1, new operators.Mul(2, 3))).toString()).toBe("(+ 1 (* 2 3))")
			# (* m (** c 2))
			expect((new operators.Mul("m", new operators.Pow("c", 2))).toString()).toBe("(* m (** c 2))")