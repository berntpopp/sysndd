<template>
  <div class="download-buttons">
    <b-button
      size="sm"
      class="float-right"
      @click="downloadPNG"
    >
      Download as PNG
    </b-button>
    <b-button
      size="sm"
      class="float-right mr-2"
      @click="downloadSVG"
    >
      Download as SVG
    </b-button>
  </div>
</template>

<script>
import html2canvas from 'html2canvas';
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
  methods: {
    /**
     * Converts the D3 plot to PNG and triggers a download.
     */
    async downloadPNG() {
      const svgElement = document.getElementById(this.svgId);
      const svgString = new XMLSerializer().serializeToString(svgElement);

      // Create a canvas element
      const canvas = document.createElement('canvas');
      const canvasWidth = 760; // Width of the canvas
      const canvasHeight = 500; // Height of the canvas
      canvas.width = canvasWidth;
      canvas.height = canvasHeight;
      const context = canvas.getContext('2d');

      // Create an image element
      const img = new Image();
      const svgBlob = new Blob([svgString], { type: 'image/svg+xml;charset=utf-8' });
      const url = URL.createObjectURL(svgBlob);

      img.onload = () => {
        context.drawImage(img, 0, 0, canvasWidth, canvasHeight);
        URL.revokeObjectURL(url);

        // Convert canvas to PNG and trigger download
        canvas.toBlob((blob) => {
          saveAs(blob, `${this.fileName}.png`);
        });
      };

      img.src = url;
    },

    /**
     * Triggers a download of the SVG element.
     */
    downloadSVG() {
      const svgElement = document.getElementById(this.svgId);
      const svgString = new XMLSerializer().serializeToString(svgElement);
      const svgBlob = new Blob([svgString], { type: 'image/svg+xml;charset=utf-8' });
      saveAs(svgBlob, `${this.fileName}.svg`);
    },
  },
};
</script>

<style scoped>
.download-buttons {
  display: inline-block;
}
</style>
