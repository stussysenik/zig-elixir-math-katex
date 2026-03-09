import { loadScriptOnce } from "./load_script"

export const DesmosHook = {
  mounted() {
    this.handleEvent("desmos:update", ({graph}) => this.renderGraph(graph))
    loadScriptOnce("desmos", "https://www.desmos.com/api/v1.11/calculator.js?apiKey=desmos")
      .then(() => this.renderGraph(this.readGraph()))
      .catch(() => {
        this.el.innerHTML = "<div class=\"flex h-full items-center justify-center text-sm text-stone-500\">Desmos failed to load.</div>"
      })
  },

  updated() {
    this.renderGraph(this.readGraph())
  },

  initCalculator() {
    if (!window.Desmos) {
      return null
    }

    if (!this.calculator) {
      this.calculator = window.Desmos.GraphingCalculator(this.el, {
        expressions: true,
        settingsMenu: false,
        zoomButtons: true,
        expressionsTopbar: false,
      })
    }

    return this.calculator
  },

  readGraph() {
    try {
      return JSON.parse(this.el.dataset.config || "{}")
    } catch (_error) {
      return {}
    }
  },

  renderGraph(graph) {
    const calculator = this.initCalculator()

    if (!calculator) {
      this.el.innerHTML = "<div class=\"flex h-full items-center justify-center text-sm text-stone-500\">Desmos is loading...</div>"
      return
    }

    if (!graph || !graph.expression) {
      calculator.setBlank()
      return
    }

    const viewport = graph.viewport || {}

    calculator.setBlank()
    calculator.setMathBounds({
      left: viewport.xmin ?? -10,
      right: viewport.xmax ?? 10,
      bottom: viewport.ymin ?? -10,
      top: viewport.ymax ?? 10,
    })
    calculator.setExpression({id: "main", latex: graph.expression})
  },
}
