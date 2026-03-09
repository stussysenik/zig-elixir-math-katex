import { loadScriptOnce } from "./load_script"

export const GeoGebraHook = {
  mounted() {
    this.handleEvent("geogebra:update", ({graph}) => this.renderGraph(graph))
    loadScriptOnce("geogebra", "https://www.geogebra.org/apps/deployggb.js")
      .then(() => this.renderGraph(this.readGraph()))
      .catch(() => {
        this.el.innerHTML = "<div class=\"flex h-full items-center justify-center text-sm text-stone-500\">GeoGebra failed to load.</div>"
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
      this.el.innerHTML = "<div class=\"flex h-full items-center justify-center text-sm text-stone-500\">GeoGebra is waiting for a verified graph payload.</div>"
      return
    }

    if (!window.GGBApplet) {
      this.el.innerHTML = "<div class=\"flex h-full items-center justify-center text-sm text-stone-500\">GeoGebra is loading...</div>"
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
        this.el.innerHTML = "<div class=\"flex h-full items-center justify-center text-sm text-stone-500\">GeoGebra could not evaluate the verified command.</div>"
      }
    }, 400)
  },
}
