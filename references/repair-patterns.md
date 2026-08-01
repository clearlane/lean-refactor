# Repair Patterns

Non-normative recipes for confirmed SSOT findings. Approval, Hard-Cut, worktree, TDD, and verification rules remain canonical in `../SKILL.md` and `repair-agent-prompt.md`; examples below never override them.

---

## Pattern 1: Thread Missing Field Through Registry Loop

**Smell**: A spec/registry carries metadata; one consumer reads it, another silently drops it.

**Example diagnosis**:
```
ef_field_specs() returns [{ key, kind, label, placeholder, types, scope }]
- Scalar consumer: reads `placeholder` — PASS
- Row consumer: ignores `placeholder` — FAIL
```

**Transform**:
```php
// Before — row consumer
$field = $kinds[ $spec['kind'] ]( $spec['key'] )->label( $spec['label'] );

// After — thread placeholder
$field = $kinds[ $spec['kind'] ]( $spec['key'] )->label( $spec['label'] );
if ( isset( $spec['placeholder'] ) ) {
    $field->placeholder( $spec['placeholder'] );
}
```

**Verification**: Lint + visual check that placeholders appear in the consumer's UI surface.

**Compound effect**: Every entry in the registry inherits the threaded field. Adding a new spec entry needs no consumer change.

---

## Pattern 2: Hoist Per-Class Statics to Global Helpers

**Smell**: Multiple classes declare the same `private static function X()` verbatim.

**Transform**:
1. Move the function to a shared location (`helpers.php`, `Concerns\X.php`, `lib/x.ts`)
2. Rename to `ef_x()` / `package_x()` / `useX()`
3. Replace each `self::X()` callsite with the global
4. Delete the class statics

**Verification**: Apply canonical evidence policy: rerun discovery-recorded exact query with unchanged root, scope, and exclusions; require baseline positive matches, post-repair zero legacy matches, and positive control matching canonical helper. Lint passes.

**Compound effect**: New widgets that need the helper get it for free.

---

## Pattern 3: PHP→CSS Variant Generation

**Smell**: Same modifier set hand-coded in multiple CSS files but already exists as a PHP constant.

**Transform**:
1. Identify the SSOT constant (e.g. `BUTTON_VARIANTS`, `CARD_VARIANTS`)
2. Add a generator method on the constant's class:
   ```php
   public static function variants_css(): string {
       $css = '';
       foreach ( self::CARD_VARIANTS as $name => $slots ) {
           $selector = ".ef-card--{$name}";
           $css .= $selector . '{' . /* declarations from $slots */ . '}';
       }
       return $css;
   }
   ```
3. Hook the generator output into the inline-style emission (existing pattern: `wp_add_inline_style`)
4. Delete the hand-written variant blocks from the CSS source files

**Verification**: Compare generated output with old hand-written CSS — they should be byte-equivalent (or document the intentional diff).

**Compound effect**: New variant = one PHP constant edit. CSS auto-generates.

---

## Pattern 4: Trait Composition

**Smell**: 3+ classes declare the same private field + setter + getter.

**Transform**:
1. Create `traits/HasX.php`:
   ```php
   trait Has_X_Trait {
       private ?string $x = null;
       public function set_x( ?string $value ): self { $this->x = $value; return $this; }
       protected function x_prop(): array { return [ 'x' => $this->x ]; }
   }
   ```
2. `use Has_X_Trait;` in each class
3. Each class merges the trait's contribution into its prop/output

**Verification**: Lint each class for orphaned private fields.

**Compound effect**: Future classes opt in with one `use` line.

---

## Pattern 5: Default-Value SSOT (placeholder ← default's option label)

**Smell**: A select control declares both `->default('white')` AND `->set_placeholder('White')`. Two strings to keep in lockstep.

**Transform**: Teach the select-pair helper to derive placeholder automatically:
```php
function ef_seeded_select( string $key, array $options, string $default ): array {
    $prop = ef_seed( String_Prop_Type::make()->enum( array_keys( $options ) ), $default );
    $control = EF_Vx_Select_Control::bind_to( $key )
        ->set_options( ef_select_options( $options ) )
        ->set_placeholder( $options[ $default ] ?? '' );
    return [ 'prop' => $prop, 'control' => $control ];
}
```

Replace each manual `->set_placeholder()` matching the default's label.

**Verification**: Rerun discovery-recorded exact query with unchanged root, scope, and exclusions; require baseline positive redundant matches, post-repair zero redundant matches, and positive control matching canonical derived-placeholder path.

**Compound effect**: Default and placeholder can never drift. Eliminates an entire class of bugs.

---

## Pattern 6: Constants for Repeated Literals

**Smell**: The same literal string (template, magic number, breakpoint) appears in N files.

**Transform**:
1. Identify the semantic name for the literal
2. Create a constants class / module:
   ```php
   class EF_Voxel_Templates {
       public const POST_TITLE  = '@tags()@post(title)@endtags()';
       public const POST_AUTHOR = '@tags()@post(author-name)@endtags()';
   }
   ```
3. Replace each literal with the named constant

**Verification**: Apply canonical evidence policy: rerun discovery-recorded exact literal query with unchanged root, scope, and exclusions; require baseline positive matches, post-repair zero legacy-literal matches, and positive control matching canonical constant declaration/use.

**Compound effect**: Upstream API rename = 1 edit. Authors get autocomplete in IDEs.

---

## Pattern 7: Twig Partials (or template fragments)

**Smell**: A 5–10 line fragment is duplicated across templates. Or a partial file exists but no `{% include %}` references it.

**Transform**:
1. Extract the fragment into `templates/partials/X.html.twig`
2. Replace each duplicate with `{% include 'partials/X' with { ... } %}`
3. If an orphan partial exists, audit its content vs current duplicates and unify

**Verification**: Rerun discovery-recorded fragment and include queries with unchanged root, scope, and exclusions; require baseline positive duplicate matches, post-repair zero legacy-fragment matches, and positive control matching canonical partial plus expected includes.

**Compound effect**: New widget reusing the fragment = one include line, not 10 lines of copy-paste.

---

## Pattern 8: Declarative Class Properties (replace constructor boilerplate)

**Smell**: Each subclass `__construct` instantiates the same set of dependencies with slight per-class variation.

**Transform**:
1. Declare the variation as a static property:
   ```php
   protected static array $parts = [
       'media' => [ EF_Part_Media::class, 'media' ],
       'logo'  => [ EF_Part_Media::class, 'logo' ],
   ];
   ```
2. Move construction logic to a base trait that walks the property
3. Remove per-class `__construct` overrides

**Verification**: Each subclass shrinks; no behavior change.

**Compound effect**: New widget with parts = static property edit. No constructor needed.

---

## Pattern 9: Auto-Flatten Registry

**Smell**: N classes each override the same method (e.g. `get_atomic_settings`) to call the same flatten helper on different keys.

**Transform**:
1. Declare the keys as a static property:
   ```php
   protected static array $responsive_string_keys = [ 'layout', 'col_span' ];
   protected static array $responsive_boolean_keys = [ 'sticky' ];
   ```
2. Have the trait walk them in the base method
3. Remove each subclass's override

**Verification**: Each subclass shrinks; trait test passes for the union of all keys.

**Compound effect**: New responsive prop = one entry in the static array. Never miss a flatten.

---

## Pattern Selection Cheat-Sheet

| Smell | Pattern |
|---|---|
| `// keep both copies in sync` comment | 1 (thread) or 6 (constant) |
| Duplicate `*_pair()` statics | 2 (hoist) |
| Hand-coded variant CSS for shared modifier set | 3 (PHP→CSS gen) |
| Same private field + setter in N classes | 4 (trait) |
| Manual placeholder restating default's label | 5 (default SSOT) |
| Same literal string in N files | 6 (constant) |
| Verbatim Twig fragment in N templates | 7 (partial) |
| N constructors instantiating the same dependencies | 8 (declarative property) |
| N method overrides calling the same flatten helper | 9 (auto-flatten) |

## Applying recipes

Use recipe only when canonical evidence is `confirmed`, including complete dynamic/indirect and persisted-store surfaces plus semantic equivalence; unqueryable stores remain `blocked`. Execute through `repair-agent-prompt.md` with mutation-sensitive focused tests and raw artifacts. Treat snippets as examples, not policy.
