import { loadScriptOnce } from "./load_script"

export const GeoGebraHook = {
  mounted() {
    this.handleEvent("geogebra:update", ({graph}) => this.renderGraph(graph))
    loadScriptOnce("geogebra", "https://www.geogebra.org/apps/deployggb.js")
      .then(() => this.renderGraph(this.readGraph()))
      .catch(() => {
        this.renderShell("bg-stone-100")
      })
  },

  updated() {
    this.renderGraph(this.readGraph())
  },

  readGraph() {
    try {
      return JSON.parse(this.el.dataset.config || "{}")
    } catch (_error) {
      return {}
    }
  },

  renderGraph(graph) {
    if (!graph || !graph.command) {
      this.renderShell("bg-stone-50")
      return
    }

    if (!window.GGBApplet) {
      this.renderShell("animate-pulse bg-stone-100")
      return
    }

    const mount = document.createElement("div")
    mount.className = "h-full w-full"
    this.el.replaceChildren(mount)

    const applet = new window.GGBApplet(
      {
        appName: "graphing",
        width: this.el.clientWidth || 640,
        height: this.el.clientHeight || 352,
        showToolBar: false,
        showMenuBar: false,
        showAlgebraInput: false,
        enableShiftDragZoom: true,
      },
      true,
    )

    applet.inject(mount)

    window.setTimeout(() => {
      try {
        const api = applet.getAppletObject?.()
        api?.evalCommand(graph.command)
      } catch (_error) {
        this.renderShell("bg-stone-100")
      }
    }, 400)
  },

  renderShell(tone) {
    this.el.innerHTML = `<div class="h-full w-full ${tone}"></div>`
  },
}
