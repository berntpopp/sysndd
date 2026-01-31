<!-- views/components/small/DownloadImageButtons.vue -->
<template>
  <div class="download-buttons">
    <BButton
      v-b-tooltip.hover.bottom
      class="download-button"
      size="sm"
      title="Download as PNG"
      :disabled="downloadingPNG"
      @click="downloadPNG"
    >
      <i v-if="!downloadingPNG" class="bi bi-image" />
      <BSpinner v-if="downloadingPNG" small />
      PNG
    </BButton>
    <BButton
      v-b-tooltip.hover.bottom
      class="download-button"
      size="sm"
      title="Download as SVG"
      :disabled="downloadingSVG"
      @click="downloadSVG"
    >
      <i v-if="!downloadingSVG" class="bi bi-file-earmark" />
      <BSpinner v-if="downloadingSVG" small />
      SVG
    </BButton>
  </div>
</template>

<script>
import { saveAs } from 'file-saver';

export default {
  name: 'DownloadImageButtons',
  props: {
    svgId: {
      type: String,
      required: true,
    },
    fileName: {
      type: String,
      default: 'plot',
    },
  },
  data() {
    return {
      downloadingPNG: false,
      downloadingSVG: false,
    };
  },
  methods: {
    async downloadPNG() {
      this.downloadingPNG = true;
      try {
        const svgElement = document.getElementById(this.svgId);
        const svgString = new XMLSerializer().serializeToString(svgElement);

        const canvas = document.createElement('canvas');
        const canvasWidth = 760;
        const canvasHeight = 500;
        canvas.width = canvasWidth;
        canvas.height = canvasHeight;
        const context = canvas.getContext('2d');

        const img = new Image();
        const svgBlob = new Blob([svgString], { type: 'image/svg+xml;charset=utf-8' });
        const url = URL.createObjectURL(svgBlob);

        img.onload = () => {
          context.drawImage(img, 0, 0, canvasWidth, canvasHeight);
          URL.revokeObjectURL(url);

          canvas.toBlob((blob) => {
            saveAs(blob, `${this.fileName}.png`);
          });
        };

        img.src = url;
      } catch (error) {
        console.error(error);
      } finally {
        this.downloadingPNG = false;
      }
    },
    async downloadSVG() {
      this.downloadingSVG = true;
      try {
        const svgElement = document.getElementById(this.svgId);
        const svgString = new XMLSerializer().serializeToString(svgElement);
        const svgBlob = new Blob([svgString], { type: 'image/svg+xml;charset=utf-8' });
        saveAs(svgBlob, `${this.fileName}.svg`);
      } catch (error) {
        console.error(error);
      } finally {
        this.downloadingSVG = false;
      }
    },
  },
};
</script>

<style scoped>
.download-buttons {
  display: inline-block;
}

.download-button {
  margin: 0.1rem 0.1rem; /* Vertical margin for small screens */
}
</style>
