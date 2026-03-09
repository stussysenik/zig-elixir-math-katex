const pendingLoads = new Map()

export function loadScriptOnce(key, src) {
  if (pendingLoads.has(key)) {
    return pendingLoads.get(key)
  }

  const promise = new Promise((resolve, reject) => {
    const existing = document.querySelector(`script[data-loader-key="${key}"]`)

    if (existing) {
      if (existing.dataset.loaded === "true") {
        resolve()
      } else {
        existing.addEventListener("load", () => resolve(), {once: true})
        existing.addEventListener("error", () => reject(new Error(`failed to load ${src}`)), {once: true})
      }

      return
    }

    const script = document.createElement("script")
    script.src = src
    script.defer = true
    script.dataset.loaderKey = key
    script.addEventListener(
      "load",
      () => {
        script.dataset.loaded = "true"
        resolve()
      },
      {once: true},
    )
    script.addEventListener("error", () => reject(new Error(`failed to load ${src}`)), {once: true})
    document.head.appendChild(script)
  })

  pendingLoads.set(key, promise)
  return promise
}
