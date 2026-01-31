<template>
  <BCard class="markdown-cheatsheet bg-light">
    <BCardBody class="py-2">
      <h6 class="mb-2 fw-semibold">
        <i class="bi bi-markdown me-1" />
        Markdown Quick Reference
      </h6>
      <BRow>
        <BCol sm="6" md="4">
          <h6 class="small text-muted mb-1">Text Formatting</h6>
          <ul class="list-unstyled small mb-2">
            <li><code>**bold**</code> = <strong>bold</strong></li>
            <li><code>_italic_</code> = <em>italic</em></li>
            <li><code>`code`</code> = <code>code</code></li>
            <li><code>~~strike~~</code> = <s>strike</s></li>
          </ul>
        </BCol>
        <BCol sm="6" md="4">
          <h6 class="small text-muted mb-1">Headers</h6>
          <ul class="list-unstyled small mb-2">
            <li><code># Heading 1</code></li>
            <li><code>## Heading 2</code></li>
            <li><code>### Heading 3</code></li>
          </ul>
        </BCol>
        <BCol sm="6" md="4">
          <h6 class="small text-muted mb-1">Lists</h6>
          <ul class="list-unstyled small mb-2">
            <li><code>- Item</code> (bullet)</li>
            <li><code>1. Item</code> (numbered)</li>
            <li><code>- [ ] Task</code> (checkbox)</li>
          </ul>
        </BCol>
        <BCol sm="6" md="4">
          <h6 class="small text-muted mb-1">Links & Images</h6>
          <ul class="list-unstyled small mb-2">
            <li><code>[text](url)</code> = link</li>
            <li><code>![alt](url)</code> = image</li>
          </ul>
        </BCol>
        <BCol sm="6" md="4">
          <h6 class="small text-muted mb-1">Blockquote</h6>
          <ul class="list-unstyled small mb-2">
            <li><code>> Quote text</code></li>
            <li><code>---</code> = horizontal line</li>
          </ul>
        </BCol>
        <BCol sm="6" md="4">
          <h6 class="small text-muted mb-1">Code Block</h6>
          <ul class="list-unstyled small mb-2">
            <li><code>```</code></li>
            <li><code>code here</code></li>
            <li><code>```</code></li>
          </ul>
        </BCol>
      </BRow>
    </BCardBody>
  </BCard>
</template>

<script setup lang="ts">
// No logic needed - pure presentation component
</script>

<style scoped>
.markdown-cheatsheet code {
  background: #fff;
  padding: 0.125rem 0.375rem;
  border-radius: 0.25rem;
  font-size: 0.8rem;
}

.markdown-cheatsheet ul {
  padding-left: 0;
}

.markdown-cheatsheet li {
  margin-bottom: 0.25rem;
}
</style>
