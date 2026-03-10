import { loadScriptOnce } from "./load_script";

export const DesmosHook = {
  mounted() {
    this.el.dataset.hasExpressions = "false";
    this.handleEvent("update_graph", (payload) => this.renderGraph(payload));
    loadScriptOnce("desmos", this.scriptUrl())
      .then(() => {
        this.scriptLoaded = true;
        this.renderGraph(this.readGraph());
      })
      .catch(() => {
        this.renderShell("bg-stone-100");
      });
  },

  updated() {
    this.renderGraph(this.readGraph());
  },

  destroyed() {
    if (this.calculator) {
      this.calculator.destroy();
      this.calculator = null;
    }
  },

  initCalculator() {
    if (!window.Desmos) {
      return null;
    }

    if (!this.calculator) {
      this.calculator = window.Desmos.GraphingCalculator(this.el, {
        expressions: true,
        settingsMenu: false,
        zoomButtons: true,
        expressionsTopbar: false,
      });
    }

    return this.calculator;
  },

  scriptUrl() {
    const apiKey =
      document
        .querySelector('meta[name="math-viz-desmos-api-key"]')
        ?.getAttribute("content") || "dcb31709b452b1cf9dc26972add0fda6";

    return `https://www.desmos.com/api/v1.11/calculator.js?apiKey=${apiKey}`;
  },

  readGraph() {
    try {
      return JSON.parse(this.el.dataset.config || "{}");
    } catch (_error) {
      return {};
    }
  },

  renderGraph(graph) {
    const calculator = this.initCalculator();

    if (!calculator) {
      if (!this.scriptLoaded) {
        this.renderShell("animate-pulse bg-stone-100");
      }

      return;
    }

    const expressions = Array.isArray(graph?.expressions)
      ? graph.expressions
      : [];

    if (expressions.length === 0) {
      calculator.setBlank();
      this.el.dataset.hasExpressions = "false";
      return;
    }

    const viewport = graph.viewport || {};

    calculator.setBlank();
    calculator.setMathBounds({
      left: viewport.xmin ?? -10,
      right: viewport.xmax ?? 10,
      bottom: viewport.ymin ?? -10,
      top: viewport.ymax ?? 10,
    });

    expressions.forEach((expression, index) => {
      calculator.setExpression({
        id: expression.id || `expr-${index}`,
        latex: expression.latex,
      });
    });

    this.el.dataset.hasExpressions = "true";
  },

  renderShell(tone) {
    if (this.calculator) {
      return;
    }

    this.el.innerHTML = `<div class="h-full w-full ${tone}"></div>`;
  },
};
