#!/usr/bin/env python3
import json
import re
import sys

from sympy import Symbol, Integer, Float, Rational, diff, expand, factor, integrate, log, simplify, sin, cos, tan, exp, sqrt, latex
from sympy import sstr
from sympy.parsing.sympy_parser import (
    convert_xor,
    implicit_multiplication_application,
    parse_expr,
    standard_transformations,
)

TRANSFORMATIONS = standard_transformations + (implicit_multiplication_application, convert_xor)

ALLOWED_LOCALS = {
    "diff": diff,
    "integrate": integrate,
    "simplify": simplify,
    "expand": expand,
    "factor": factor,
    "sin": sin,
    "cos": cos,
    "tan": tan,
    "exp": exp,
    "log": log,
    "sqrt": sqrt,
}

SAFE_GLOBALS = {
    "__builtins__": {},
    "Symbol": Symbol,
    "Integer": Integer,
    "Float": Float,
    "Rational": Rational,
}

for symbol_name in ("x", "y", "z"):
    ALLOWED_LOCALS[symbol_name] = Symbol(symbol_name)

BLOCKED_TOKENS = {"__", "import", "eval", "exec", "open", "lambda", "os", "sys", "subprocess"}
VALID_PATTERN = re.compile(r"^[A-Za-z0-9_(),+\-*/^ .]+$")
IDENTIFIER_PATTERN = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def error_response(request_id, message):
    return {"request_id": request_id, "ok": False, "result_string": None, "result_latex": None, "normalized_expression": None, "error": message}


def validate_expression(expression):
    if not expression or len(expression) > 256:
        return "Expression is empty or too long."

    if not VALID_PATTERN.match(expression):
        return "Expression contains unsupported characters."

    lowered = expression.lower()
    for token in BLOCKED_TOKENS:
        if token in lowered:
            return f"Blocked token detected: {token}"

    identifiers = IDENTIFIER_PATTERN.findall(expression)
    for identifier in identifiers:
      if identifier not in ALLOWED_LOCALS:
          return f"Unsupported identifier: {identifier}"

    return None


def execute_expression(expression):
    parsed = parse_expr(
        expression,
        local_dict=ALLOWED_LOCALS,
        global_dict=SAFE_GLOBALS,
        transformations=TRANSFORMATIONS,
        evaluate=True,
    )
    return {
        "result_string": sstr(parsed),
        "result_latex": latex(parsed),
        "normalized_expression": sstr(parsed),
    }


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue

        try:
            payload = json.loads(line)
            request_id = payload.get("request_id", "unknown")
            expression = payload.get("sympy_executable", "")

            validation_error = validate_expression(expression)
            if validation_error:
                response = error_response(request_id, validation_error)
            else:
                result = execute_expression(expression)
                response = {"request_id": request_id, "ok": True, "error": None, **result}
        except Exception as exc:  # noqa: BLE001
            request_id = payload.get("request_id", "unknown") if "payload" in locals() and isinstance(payload, dict) else "unknown"
            response = error_response(request_id, str(exc))

        sys.stdout.write(json.dumps(response) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
