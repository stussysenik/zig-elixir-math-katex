export const KeyboardSubmitHook = {
  mounted() {
    this.onKeyDown = (event) => {
      if (event.isComposing || event.key !== "Enter") {
        return;
      }

      if (!(event.metaKey || event.ctrlKey) || event.altKey || event.shiftKey) {
        return;
      }

      const form = this.el.form;

      if (!form) {
        return;
      }

      event.preventDefault();
      form.requestSubmit();
    };

    this.el.addEventListener("keydown", this.onKeyDown);
  },

  destroyed() {
    this.el.removeEventListener("keydown", this.onKeyDown);
  },
};
