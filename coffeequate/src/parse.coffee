define ["require"], (require) ->

	# Functions to parse strings into various Coffeequate objects.

	class ParseError extends Error
		constructor: (@input, @type) ->

		toString: ->
			"Could not parse '#{@input}' as #{@type}"

	VARIABLE_REGEX = /^@*[a-zA-Z\u0391-\u03A9\u03B1-\u03C9][a-zA-Z\u0391-\u03A9\u03B1-\u03C9_\-\d]*$/
	CONSTANT_REGEX = /^-?\d+(\.\d+)?(e-?\d+(\.\d+)?)?$/
	RATIO_REGEX = /^-?\d+(\.\d+)?\/\d+(\.\d+)?$/
	SYMBOLIC_CONSTANT_REGEX = /^\\@*[a-zA-Z\u0391-\u03A9\u03B1-\u03C9][a-zA-Z\u0391-\u03A9\u03B1-\u03C9_\-\d]*$/
	DIMENSIONS_REGEX = /^[^:]*::\{[^:+]*\}$/

	stringToTerminal = (string) ->
		# Take a string and return a Terminal that that string represents.
		# E.g. "2" -> Constant(2)
		# E.g. "v" -> Variable(2)
		if /\^/.test(string)
			throw new Error("Unexpected carat (^). Coffeequate uses ** for exponentiation")
		if DIMENSIONS_REGEX.test(string)
			segments = string.split("::")
			terminal = stringToTerminal(segments[0])
			terminal.units = new StringToExpression(segments[1][1...segments[1].length-1])
			return terminal
		string = string.trim()
		terminals = require("terminals")
		if CONSTANT_REGEX.test(string) or RATIO_REGEX.test(string)
			return new terminals.Constant(string)
		else if VARIABLE_REGEX.test(string)
			if string[0] == "σ"
				return new terminals.Uncertainty(string[1..])
			return new terminals.Variable(string)
		else if SYMBOLIC_CONSTANT_REGEX.test(string)
			return new terminals.SymbolicConstant(string[1..])
		else
			throw new ParseError(string, "terminal")

	class StringToExpression
		# A parser which parses an expression string into an expression.
		# E.g. "1 + 2 * 3 ** 4" -> Add(1, Mul(2, Pow(3, 4)))

		###
			ADDN := MULT | ADDN "+" MULT
			MULT := POWR | MULT "*" POWR
			POWR := BRAC | POWR "**" BRAC
			BRAC := "-" BRAC | "(" ADDN ")" | TERM
			TERM := <Existing Code>
		###

		# Any strangeness in this parser is probably because I accidentally wrote it backwards.

		constructor: (string, simplify = true) ->
			@tokens = StringToExpression.tokenise(string).reverse()
			@upto = 0
			@operators = require("operators")
			parseResult = @parseAddition()
			if simplify
				parseResult = parseResult.expandAndSimplify()

			return parseResult # Return a node instead of returning this parser class.

		@tokenise: (string) ->
			# Convert a string into an array of token strings.
			string.split(/(\*\*|[+*()\-:]|\s)/).filter((z) -> !/^\s*$/.test(z))

		getToken: ->
			@tokens[@upto]

		parseAddition: ->
			# We know we have to have a MULT to start with, so parse that.
			mult = @parseMultiplication()

			# Expect a "+".
			unless @getToken() == "+"
				# We must have only had a MULT after all.
				return mult

			@upto += 1

			# Now we have another ADDN.
			addn = @parseAddition()

			# We're done!
			return new @operators.Add(addn, mult)

		parseMultiplication: ->
			# We know we have to have a POWR to start with, so parse that.
			powr = @parsePower()

			# Expect a "*".
			if @getToken() and VARIABLE_REGEX.test(@getToken())
				throw new ParseError(@getToken(), "multiplication")
			unless @getToken() == "*"
				# We must have only had a POWR after all.
				return powr

			@upto += 1

			# Now we have another MULT.
			mult = @parseMultiplication()

			# We're done!
			return new @operators.Mul(mult, powr)

		parsePower: ->
			# We know we have to have a BRAC to start with, so parse that.
			brac = @parseBracket()

			# Expect a "**".
			unless @getToken() == "**"
				# We must have only had a BRAC after all.
				return brac

			@upto += 1

			# Now we have another POWR.
			powr = @parsePower()

			# We're done!
			return new @operators.Pow(powr, brac)

		parseBracket: ->
			# BRAC := "-" BRAC | "(" ADDN ")" | TERM
			# Do we start with a ")"?
			# Because I wrote this backwards...
			if @getToken() == ")"
				# We do!
				# Now we have another ADDN.
				@upto += 1
				addn = @parseAddition()

				# We should have a closing bracket.
				unless @getToken() == "("
					throw new Error("ParseError: Expected '(' but found '#{@getToken()}' at position " +
						"#{@tokens.length - @upto}/#{@tokens.length} in token stream '#{@tokens.reverse().join(" ")}'")

				@upto += 1

				# We're done, almost!

				# Do we have a negative sign?
				if @getToken() == "-" # Yeah, I wrote this backwards.
					@upto += 1
					return new @operators.Mul(-1, addn)
				else
					return addn

			# Nothing else, so we must have a TERM!
			else
				term = @parseTerm()

				# We're done, unless we are followed by a minus sign (because I wrote this backwards).
				if @getToken() == "-"
					@upto += 1
					return new @operators.Mul(-1, term)
				else
					return term

		parseTerm: ->
			# Do we have term::{} or just term?
			terminal = []
			if @getToken()[@getToken().length - 1] == "}"
				while @getToken()[0] != ":"
					terminal.push(@getToken())
					@upto += 1
				terminal.push(@getToken())
				@upto += 1
				terminal.push(@getToken())
				@upto += 1
				terminal.push(@getToken())
				term = stringToTerminal(terminal.reverse().join(""))
			else
				term = stringToTerminal(@getToken())

			@upto += 1
			return term

	return {

		ParseError: ParseError

		stringToExpression: (string, simplify=true) ->
			return new StringToExpression(string, simplify)

		constant: (value) ->
			# Take a string and return [numerator, denominator].

			if typeof(value) == "string" or value instanceof String
				## TODO: Use regex here!
				if value == "" then throw new ParseError("", "constant")

				value = value.split("/")
				if value.length == 1
					return [parseFloat(value[0]), 1]
				else if value.length == 2
					return [parseFloat(value[0]), parseFloat(value[1])]
				else
					throw new ParseError(value.join("/"), "constant")

			else if typeof(value) == "number" or value instanceof Number
				## TODO: Convert the number into a fraction if necessary.
				return [value, 1]

			else
				throw new ParseError(value, "constant")

		stringToTerminal: stringToTerminal

	}