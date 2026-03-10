export const VisionDropzoneHook = {
  mounted() {
    this.dragDepth = 0
    this.dragClasses = ["ring-2", "ring-dashed", "ring-slate-400", "bg-slate-50"]
    this.fileInput = this.el.querySelector("#vision-upload")
    this.fileLabel = this.el.querySelector("[data-testid='vision-file-label']")

    this.onDragEnter = event => {
      if (!this.hasFiles(event)) return
      event.preventDefault()
      this.dragDepth += 1
      this.setDragState(true)
    }

    this.onDragOver = event => {
      if (!this.hasFiles(event)) return
      event.preventDefault()
      this.setDragState(true)
    }

    this.onDragLeave = event => {
      if (!this.hasFiles(event)) return
      event.preventDefault()
      this.dragDepth = Math.max(0, this.dragDepth - 1)

      if (this.dragDepth === 0) {
        this.setDragState(false)
      }
    }

    this.onDrop = event => {
      if (!this.hasFiles(event)) return
      event.preventDefault()
      this.dragDepth = 0
      this.setDragState(false)

      const [file] = Array.from(event.dataTransfer?.files || [])
      this.updateFileLabel(file)
    }

    this.onFileChange = event => {
      const [file] = Array.from(event.target.files || [])
      this.updateFileLabel(file)
    }

    window.addEventListener("dragenter", this.onDragEnter)
    window.addEventListener("dragover", this.onDragOver)
    window.addEventListener("dragleave", this.onDragLeave)
    window.addEventListener("drop", this.onDrop)
    this.fileInput?.addEventListener("change", this.onFileChange)
  },

  destroyed() {
    window.removeEventListener("dragenter", this.onDragEnter)
    window.removeEventListener("dragover", this.onDragOver)
    window.removeEventListener("dragleave", this.onDragLeave)
    window.removeEventListener("drop", this.onDrop)
    this.fileInput?.removeEventListener("change", this.onFileChange)
  },

  hasFiles(event) {
    return Array.from(event.dataTransfer?.types || []).includes("Files")
  },

  setDragState(active) {
    this.el.classList.toggle("ring-2", active)
    this.el.classList.toggle("ring-dashed", active)
    this.el.classList.toggle("ring-slate-400", active)
    this.el.classList.toggle("bg-slate-50", active)
  },

  updateFileLabel(file) {
    if (!this.fileLabel) return

    if (file?.name) {
      this.fileLabel.textContent = `Selected image: ${file.name}`
    } else {
      this.fileLabel.textContent =
        "Enter a query, or drag & drop textbook photos and whiteboard sketches (JPG/PNG/WebP, max 5MB)."
    }
  },
}
