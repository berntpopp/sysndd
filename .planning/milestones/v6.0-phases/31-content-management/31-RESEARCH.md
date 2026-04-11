# Phase 31: Content Management - Research

**Researched:** 2026-01-25
**Domain:** CMS Editor, Markdown Rendering, Draft/Publish Workflow, Vue 3
**Confidence:** HIGH

## Summary

This research investigates how to build a CMS editor for the ManageAbout page with draft/publish workflow. The core challenges are: (1) choosing appropriate markdown editor/renderer libraries compatible with Vue 3 and Bootstrap-Vue-Next, (2) implementing scroll sync between editor and preview, (3) supporting drag-and-drop section reordering, and (4) designing a database schema for per-user drafts with version history.

The existing SysNDD codebase provides strong patterns to follow: the `useFormDraft` composable for auto-save, the R Plumber API patterns for CRUD operations (see `ontology_endpoints.R`), and admin UI patterns from `ManageUser.vue` and `ManageOntology.vue`. The current About.vue has 7 accordion sections with custom Bootstrap Icons that must be preserved in the CMS data model.

**Primary recommendation:** Use a lightweight approach with plain textarea + toolbar buttons (not a heavy editor library), markdown-it for rendering with DOMPurify sanitization, vue-dompurify-html directive for safe v-html replacement, and vuedraggable@next for section reordering.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| markdown-it | ^14.x | Markdown parsing to HTML | More extensible than marked, excellent plugin ecosystem, active maintenance |
| DOMPurify | ^3.x | XSS sanitization | Industry standard for HTML sanitization, required for any v-html usage |
| vue-dompurify-html | ^5.x | Safe v-html directive | Vue 3 compatible wrapper, replaces v-html with sanitized version |
| vuedraggable@next | ^4.x | Drag-and-drop reordering | Official SortableJS Vue 3 adapter, well-maintained |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| lodash-es/debounce | (bundled) | Debounce preview updates | For 300ms preview debounce requirement |
| @vueuse/core | ^14.x (existing) | Composables | Already in project - useLocalStorage, useDebounceFn, onClickOutside |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Plain textarea + toolbar | md-editor-v3 | md-editor-v3 is feature-rich but heavy (~200KB), harder to style with Bootstrap |
| markdown-it | marked | marked has had more XSS CVEs historically, less plugin support |
| vuedraggable@next | VueUse useSortable | useSortable is simpler but vuedraggable has better Vue integration |

**Installation:**
```bash
npm install markdown-it dompurify vue-dompurify-html vuedraggable@next
npm install -D @types/dompurify @types/markdown-it
```

## Architecture Patterns

### Recommended Project Structure
```
src/
├── views/admin/
│   └── ManageAbout.vue          # Main CMS editor page
├── components/cms/
│   ├── MarkdownEditor.vue       # Textarea + toolbar component
│   ├── MarkdownPreview.vue      # Rendered preview with scroll sync
│   ├── SectionEditor.vue        # Single section (title, icon, content)
│   ├── SectionList.vue          # Draggable section list
│   └── MarkdownCheatsheet.vue   # Collapsible syntax reference
├── composables/
│   ├── useMarkdownRenderer.ts   # markdown-it + DOMPurify setup
│   ├── useEditorScrollSync.ts   # Editor-preview scroll synchronization
│   └── useCmsContent.ts         # API integration for content CRUD
└── types/
    └── cms.ts                   # CMS-related TypeScript interfaces
```

### Pattern 1: Minimal Toolbar Markdown Editor
**What:** Plain textarea with button toolbar above for common formatting
**When to use:** When you need Bootstrap styling compatibility and minimal bundle size
**Example:**
```typescript
// Source: Project pattern based on textarea-markdown-editor approach
interface ToolbarAction {
  icon: string;           // Bootstrap icon class
  title: string;
  prefix: string;         // Text to insert before selection
  suffix: string;         // Text to insert after selection
  placeholder?: string;   // Default text if no selection
}

const toolbarActions: ToolbarAction[] = [
  { icon: 'bi-type-bold', title: 'Bold', prefix: '**', suffix: '**', placeholder: 'bold text' },
  { icon: 'bi-type-italic', title: 'Italic', prefix: '_', suffix: '_', placeholder: 'italic text' },
  { icon: 'bi-link', title: 'Link', prefix: '[', suffix: '](url)', placeholder: 'link text' },
  { icon: 'bi-type-h1', title: 'Heading 1', prefix: '# ', suffix: '', placeholder: '' },
  { icon: 'bi-type-h2', title: 'Heading 2', prefix: '## ', suffix: '', placeholder: '' },
  { icon: 'bi-list-ul', title: 'Bullet List', prefix: '- ', suffix: '', placeholder: '' },
  { icon: 'bi-list-ol', title: 'Numbered List', prefix: '1. ', suffix: '', placeholder: '' },
];

function insertAtCursor(textarea: HTMLTextAreaElement, action: ToolbarAction) {
  const start = textarea.selectionStart;
  const end = textarea.selectionEnd;
  const selectedText = textarea.value.substring(start, end) || action.placeholder;
  const replacement = `${action.prefix}${selectedText}${action.suffix}`;

  textarea.value =
    textarea.value.substring(0, start) +
    replacement +
    textarea.value.substring(end);

  // Restore cursor position after prefix
  const newCursorPos = start + action.prefix.length + selectedText.length;
  textarea.setSelectionRange(newCursorPos, newCursorPos);
  textarea.focus();
}
```

### Pattern 2: Debounced Preview Updates
**What:** Preview renders markdown 300ms after user stops typing
**When to use:** For real-time preview without performance issues
**Example:**
```typescript
// Source: VueUse useDebounceFn pattern
import { ref, computed, watch } from 'vue';
import { useDebounceFn } from '@vueuse/core';
import MarkdownIt from 'markdown-it';
import DOMPurify from 'dompurify';

export function useMarkdownRenderer() {
  const md = new MarkdownIt({
    html: false,        // Disable HTML tags in source
    linkify: true,      // Auto-convert URLs to links
    typographer: true,  // Smart quotes, etc.
  });

  const rawMarkdown = ref('');
  const renderedHtml = ref('');

  const renderMarkdown = useDebounceFn((source: string) => {
    const html = md.render(source);
    renderedHtml.value = DOMPurify.sanitize(html, {
      ALLOWED_TAGS: ['p', 'br', 'strong', 'em', 'a', 'ul', 'ol', 'li',
                     'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'blockquote',
                     'code', 'pre', 'hr', 'table', 'thead', 'tbody',
                     'tr', 'th', 'td'],
      ALLOWED_ATTR: ['href', 'target', 'rel'],
    });
  }, 300);  // 300ms debounce per requirement

  watch(rawMarkdown, (newVal) => {
    renderMarkdown(newVal);
  });

  return { rawMarkdown, renderedHtml };
}
```

### Pattern 3: Per-User Draft with API
**What:** Drafts isolated per user, stored server-side with version history
**When to use:** Multi-admin CMS where drafts should persist across devices
**Example:**
```typescript
// Source: Adapted from existing useFormDraft.ts and API patterns
interface AboutDraft {
  draft_id: number;
  user_id: number;
  sections: AboutSection[];
  created_at: string;
  updated_at: string;
}

interface AboutSection {
  section_id: string;
  title: string;
  icon: string;           // Bootstrap icon class (e.g., 'bi-people')
  content: string;        // Markdown content
  sort_order: number;
}

// API calls follow existing patterns from user_endpoints.R
async function saveDraft(sections: AboutSection[]): Promise<void> {
  await axios.put(`${API_URL}/api/about/draft`, {
    sections
  }, {
    headers: { Authorization: `Bearer ${localStorage.getItem('token')}` }
  });
}

async function loadDraft(): Promise<AboutDraft | null> {
  const response = await axios.get(`${API_URL}/api/about/draft`, {
    headers: { Authorization: `Bearer ${localStorage.getItem('token')}` }
  });
  return response.data;
}

async function publish(sections: AboutSection[]): Promise<void> {
  await axios.post(`${API_URL}/api/about/publish`, {
    sections
  }, {
    headers: { Authorization: `Bearer ${localStorage.getItem('token')}` }
  });
}
```

### Anti-Patterns to Avoid
- **Using v-html without DOMPurify:** Even with markdown-it, always sanitize output
- **Heavy markdown editor libraries:** md-editor-v3 adds ~200KB and conflicts with Bootstrap styling
- **Client-only drafts:** Per-user server-side drafts enable cross-device editing
- **Scroll sync via percentage:** Line-based mapping is more accurate than scroll percentage

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| XSS sanitization | Custom regex filters | DOMPurify | XSS is complex, DOMPurify handles edge cases |
| Markdown parsing | Custom parser | markdown-it | Edge cases in markdown spec are extensive |
| Drag-and-drop | Custom mouse events | vuedraggable | Touch support, accessibility, animation |
| Debouncing | setTimeout wrapper | @vueuse/core useDebounceFn | Proper cleanup, TypeScript types |
| Safe v-html | v-html + manual sanitize | vue-dompurify-html | Consistent sanitization, less error-prone |

**Key insight:** Markdown/XSS libraries exist because the edge cases are numerous and security-critical. Even "simple" markdown has 20+ edge cases for code blocks, nested lists, and escaped characters.

## Common Pitfalls

### Pitfall 1: XSS via v-html
**What goes wrong:** Developers use v-html to render markdown output without sanitization
**Why it happens:** Markdown feels safe because it's "just text"
**How to avoid:**
- Use vue-dompurify-html directive instead of v-html
- Configure DOMPurify allowlist explicitly
- Never trust user-provided HTML even from markdown
**Warning signs:** Any use of `v-html` in the codebase without adjacent sanitization

### Pitfall 2: Scroll Sync Mismatch
**What goes wrong:** Editor and preview scroll positions drift apart on complex documents
**Why it happens:** Percentage-based scroll sync doesn't account for rendered height differences
**How to avoid:**
- Use line-number-based mapping (track source lines to rendered elements)
- Add data attributes to rendered elements for sync points
- Accept imperfect sync for very long documents
**Warning signs:** Preview jumps when scrolling near images/code blocks

### Pitfall 3: Draft Data Loss
**What goes wrong:** User loses work when navigating away or session expires
**Why it happens:** Autosave interval too long, beforeunload not handled
**How to avoid:**
- Autosave on blur (user clicks away from editor)
- Autosave on beforeunload
- Show "unsaved changes" indicator
- Server-side draft with user_id isolation
**Warning signs:** No save indicator visible to user

### Pitfall 4: Icon Selection Complexity
**What goes wrong:** UI for selecting Bootstrap Icons becomes overwhelming
**Why it happens:** Bootstrap Icons has 2000+ icons
**How to avoid:**
- Provide curated list of ~20 relevant icons
- Show icon preview next to dropdown
- Allow text search within curated set
**Warning signs:** Full icon picker with search feels like overkill

### Pitfall 5: Version History Bloat
**What goes wrong:** Database grows unbounded with every autosave
**Why it happens:** Storing full content on every save
**How to avoid:**
- Consolidate rapid saves (only keep latest within 5-minute window)
- Implement retention policy (keep last N versions or time-based)
- Consider delta storage for large content (optional optimization)
**Warning signs:** Content versions table growing faster than expected

## Code Examples

Verified patterns from official sources:

### vuedraggable@next Section Reordering
```vue
<!-- Source: https://github.com/SortableJS/vue.draggable.next -->
<template>
  <draggable
    v-model="sections"
    item-key="section_id"
    handle=".drag-handle"
    animation="200"
    ghost-class="ghost"
    @change="onSectionOrderChange"
  >
    <template #item="{ element, index }">
      <div class="section-item">
        <span class="drag-handle bi bi-grip-vertical"></span>
        <SectionEditor
          :section="element"
          @update="updateSection(index, $event)"
          @delete="deleteSection(index)"
        />
      </div>
    </template>
  </draggable>
</template>

<script setup lang="ts">
import draggable from 'vuedraggable';
import { ref } from 'vue';
import type { AboutSection } from '@/types/cms';

const sections = ref<AboutSection[]>([]);

function onSectionOrderChange() {
  // Update sort_order based on new array positions
  sections.value.forEach((section, index) => {
    section.sort_order = index;
  });
  // Trigger autosave
}
</script>

<style scoped>
.ghost {
  opacity: 0.5;
  background: var(--bs-primary-bg-subtle);
}
.drag-handle {
  cursor: grab;
}
</style>
```

### markdown-it + DOMPurify Setup
```typescript
// Source: https://www.npmjs.com/package/markdown-it + DOMPurify docs
import MarkdownIt from 'markdown-it';
import DOMPurify from 'dompurify';

// Create markdown-it instance with safe defaults
const md = new MarkdownIt({
  html: false,        // Disable raw HTML in markdown source
  breaks: true,       // Convert \n to <br>
  linkify: true,      // Auto-link URLs
  typographer: true,  // Smart quotes and dashes
});

// Configure DOMPurify for safe output
const sanitizeConfig = {
  ALLOWED_TAGS: [
    'p', 'br', 'strong', 'b', 'em', 'i', 'a',
    'ul', 'ol', 'li', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
    'blockquote', 'code', 'pre', 'hr',
    'table', 'thead', 'tbody', 'tr', 'th', 'td',
  ],
  ALLOWED_ATTR: ['href', 'target', 'rel', 'class'],
  ADD_ATTR: ['target'],  // Allow target="_blank"
  FORBID_TAGS: ['script', 'style', 'iframe', 'form', 'input'],
  FORBID_ATTR: ['onerror', 'onclick', 'onload'],
};

export function renderMarkdown(source: string): string {
  const rawHtml = md.render(source);
  return DOMPurify.sanitize(rawHtml, sanitizeConfig);
}
```

### Editor Height Best Practice
```vue
<!-- Source: Research finding - CSS approach -->
<template>
  <BFormTextarea
    v-model="content"
    class="markdown-editor"
    :rows="20"
    :style="{ minHeight: '400px', maxHeight: '600px', resize: 'vertical' }"
    @blur="saveDraft"
  />
</template>

<style scoped>
.markdown-editor {
  font-family: ui-monospace, SFMono-Regular, 'SF Mono', Menlo, Consolas, monospace;
  font-size: 0.9rem;
  line-height: 1.5;
  tab-size: 2;
}
</style>
```

### R Plumber API Endpoint Pattern
```r
# Source: Adapted from ontology_endpoints.R update pattern

#* Get current user's draft for About page
#* @tag about
#* @serializer json list(na="null")
#* @get draft
function(req, res) {
  require_role(req, res, "Administrator")

  user_id <- req$user_id

  draft <- db_execute_query(
    "SELECT * FROM about_content
     WHERE user_id = ? AND status = 'draft'
     ORDER BY updated_at DESC LIMIT 1",
    list(user_id)
  )

  if (nrow(draft) == 0) {
    # Return published version as starting point
    published <- db_execute_query(
      "SELECT * FROM about_content
       WHERE status = 'published'
       ORDER BY version DESC LIMIT 1",
      list()
    )
    return(published)
  }

  draft
}

#* Save draft
#* @tag about
#* @serializer json list(na="string")
#* @accept json
#* @put draft
function(req, res) {
  require_role(req, res, "Administrator")

  user_id <- req$user_id
  sections <- req$argsBody$sections

  # Validate sections structure
  if (is.null(sections) || length(sections) == 0) {
    res$status <- 400
    return(list(error = "sections array is required"))
  }

  # Upsert draft for this user
  db_with_transaction({
    # Delete existing draft for this user
    db_execute_statement(
      "DELETE FROM about_content WHERE user_id = ? AND status = 'draft'",
      list(user_id)
    )

    # Insert new draft
    db_execute_statement(
      "INSERT INTO about_content (user_id, sections_json, status, updated_at)
       VALUES (?, ?, 'draft', NOW())",
      list(user_id, jsonlite::toJSON(sections, auto_unbox = TRUE))
    )
  })

  list(message = "Draft saved successfully")
}

#* Publish content (creates new version)
#* @tag about
#* @serializer json list(na="string")
#* @accept json
#* @post publish
function(req, res) {
  require_role(req, res, "Administrator")

  user_id <- req$user_id
  sections <- req$argsBody$sections

  db_with_transaction({
    # Get next version number
    max_version <- db_execute_query(
      "SELECT COALESCE(MAX(version), 0) as max_v FROM about_content WHERE status = 'published'",
      list()
    )
    new_version <- max_version$max_v + 1

    # Insert published version
    db_execute_statement(
      "INSERT INTO about_content (user_id, sections_json, status, version, published_at, updated_at)
       VALUES (?, ?, 'published', ?, NOW(), NOW())",
      list(user_id, jsonlite::toJSON(sections, auto_unbox = TRUE), new_version)
    )

    # Clear this user's draft
    db_execute_statement(
      "DELETE FROM about_content WHERE user_id = ? AND status = 'draft'",
      list(user_id)
    )
  })

  list(message = "Content published successfully", version = new_version)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| SimpleMDE / EasyMDE | Plain textarea + toolbar | 2024+ | EasyMDE unmaintained, XSS risks, bundled dependencies |
| marked | markdown-it | 2023+ | Better plugin ecosystem, fewer CVEs |
| v-html | vue-dompurify-html | 2022+ | Built-in sanitization, safer by default |
| Vue.Draggable (vue2) | vuedraggable@next | 2021 | Vue 3 Composition API support |

**Deprecated/outdated:**
- **SimpleMDE / EasyMDE**: No longer maintained, known XSS vulnerabilities
- **marked (standalone)**: Still works but requires manual DOMPurify setup, more historical CVEs than markdown-it
- **vue-markdown-editor**: Vue 2 only, not compatible with Vue 3

## Database Schema

### Recommended Schema for About Content
```sql
-- about_content table for draft/publish workflow
CREATE TABLE IF NOT EXISTS `about_content` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT NOT NULL,                    -- FK to user table
  `sections_json` JSON NOT NULL,             -- Array of section objects
  `status` ENUM('draft', 'published') NOT NULL DEFAULT 'draft',
  `version` INT DEFAULT NULL,                -- Only set for published versions
  `published_at` TIMESTAMP NULL,             -- When published (null for drafts)
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  INDEX idx_user_status (user_id, status),
  INDEX idx_status_version (status, version DESC),

  FOREIGN KEY (user_id) REFERENCES user(user_id) ON DELETE CASCADE
);

-- Example sections_json structure:
-- [
--   {
--     "section_id": "creators",
--     "title": "About SysNDD and its creators",
--     "icon": "bi-people",
--     "content": "The SysNDD database is based on...",
--     "sort_order": 0
--   },
--   ...
-- ]
```

### Schema Rationale
1. **Single table with status column**: Simpler than separate draft/published tables
2. **JSON column for sections**: Flexible, matches frontend data structure, supports reordering
3. **Per-user drafts via user_id + status**: Each admin has isolated draft
4. **Version tracking**: `version` column only populated for published content
5. **Cascading delete**: Drafts deleted when user account removed

## Open Questions

Things that couldn't be fully resolved:

1. **Scroll sync accuracy on complex content**
   - What we know: Line-based sync is more accurate than percentage
   - What's unclear: Exact implementation for News section timeline formatting
   - Recommendation: Accept imperfect sync, prioritize for later refinement

2. **Icon picker UX**
   - What we know: Full Bootstrap Icons library has 2000+ icons
   - What's unclear: Optimal number of curated icons to offer
   - Recommendation: Start with ~20 icons matching existing About.vue sections, add more if requested

3. **Mobile editing experience**
   - What we know: Side-by-side layout doesn't fit mobile
   - What's unclear: Whether mobile CMS editing is in scope
   - Recommendation: Assume desktop-only for MVP, add responsive tabs later if needed

## Sources

### Primary (HIGH confidence)
- [vue-dompurify-html npm](https://www.npmjs.com/package/vue-dompurify-html) - Vue 3 safe HTML directive
- [vuedraggable@next GitHub](https://github.com/SortableJS/vue.draggable.next) - Vue 3 drag-and-drop
- [DOMPurify npm](https://www.npmjs.com/package/dompurify) - HTML sanitization
- [markdown-it npm](https://www.npmjs.com/package/markdown-it) - Markdown parser

### Secondary (MEDIUM confidence)
- [Implementing Synchronous Scrolling in Markdown Editor](https://dev.to/woai3c/implementing-synchronous-scrolling-in-a-dual-pane-markdown-editor-5d75) - Scroll sync techniques
- [Payload CMS Versions Documentation](https://payloadcms.com/docs/versions/overview) - Draft/publish workflow patterns
- [Vue.js Security Guide](https://vuejs.org/guide/best-practices/security) - XSS prevention in Vue

### Existing Codebase (HIGH confidence)
- `/home/bernt-popp/development/sysndd/app/src/composables/useFormDraft.ts` - Autosave patterns
- `/home/bernt-popp/development/sysndd/api/endpoints/ontology_endpoints.R` - API CRUD patterns
- `/home/bernt-popp/development/sysndd/app/src/views/admin/ManageUser.vue` - Admin UI patterns
- `/home/bernt-popp/development/sysndd/app/src/views/help/About.vue` - Current section structure

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official npm packages, well-established patterns
- Architecture: HIGH - Based on existing SysNDD patterns and Vue 3 best practices
- Database schema: MEDIUM - Follows CMS patterns but not validated against actual data volume
- Scroll sync: LOW - Multiple approaches exist, may need iteration

**Research date:** 2026-01-25
**Valid until:** 2026-02-25 (30 days - stable domain)
