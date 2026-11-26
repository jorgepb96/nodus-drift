# Simplified landscapes

The current presentation is the main photographic setting with native animated
weather, water, light and atmosphere. Decorative animal and object cutouts are
hidden everywhere: simple mixes, Studio, saved/imported scenes and director output.

`StudioVisualPolicy.decorativeActorsEnabled` is a presentation-only switch set to
`false`. Actor recipes, saved actor data, placement rules, sprite metadata, atlases
and shader composition code remain available for a future change of direction.
The renderer also rejects actor uniforms at its boundary, so a legacy or manually
constructed snapshot cannot display a cutout. Unused atlases are not loaded into
GPU memory. Audio selection and playback are unchanged. Descriptions list the
visible weather/effects without promising animals or explaining off-screen props.

Meditation retains a single native landscape surface while Nodi is selected,
pauses its animation, and resumes the existing frame when the landscape returns.
Two explicit SwiftUI buttons replace the native segmented control. Appearance
changes use a nonanimated transaction and keep the selector visible;
the existing inactivity timer still hides the controls. Nodi's wake/gaze gesture
is reset when changing appearance. This avoids surface recreation and the sudden
control disappearance during the switch while keeping hidden scenery idle.

The final iOS 26.5 simulator run passed all 17 test bodies: 15 landscape tests
and two UI flows. It covers the 3,916-pair audit, all background compatibility
rules, real GPU output with forced actor input, retained serialized recipes,
independent weather/fire motion, the same surface surviving three switches while
pausing behind Nodi, three selector round trips with uninterrupted real audio,
and appearance persistence. Early UI attempts raced the five-second controls auto-hide timer; subsequent
build-16 screenshots confirmed that some selection taps were only revealing
already-hidden controls. The UI flow now refreshes controls before selection.

Xcode stalled after successful test execution with SDK-version parsing warnings,
so the retained [console summary](SimplifiedLandscapes-console-summary.json) is the
evidence; a completed xcresult bundle is not claimed. Earlier attempts also
identified two fixture problems: the isolated hosting window needed an active
scene phase, and the UI recipe needed to select an audible catalogue row directly.
The final tests use those corrected fixtures. No physical phone tests were
performed, per the user's instruction.

The [native snow screenshot](../../screenshots/studio/simplified/snow.png) was
visually inspected: snow photograph, snowfall and footprints, without a wolf or
other cutouts. Assets were not regenerated or removed. These source changes follow
the delivered 0.2.0 (15); they have not yet been uploaded in another build.
