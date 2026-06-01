# Data Model: Controller Design

## ControllerSession

- Purpose: Represents Gaia's in-memory state for one active controller session on iPad.
- Fields:
  - `sessionId`: String, unique identifier for the controller session
  - `courseId`: String, Aither course or presentation lookup key
  - `presentationId`: String, upstream presentation identifier
  - `status`: Enum (`idle`, `loading`, `ready`, `error`, `unavailable`)
  - `activeSlideIndex`: Int
  - `lastSyncedAt`: Date?
  - `lastErrorCode`: String?
- Validation Rules:
  - `courseId` and `presentationId` are required once `status != idle`
  - `activeSlideIndex` must be within the manifest's slide bounds when `status == ready`
  - `lastErrorCode` is required when `status == error`
- State Transitions:
  - `idle -> loading -> ready`
  - `loading -> error`
  - `loading -> unavailable`
  - `ready -> loading` on refresh or navigation sync
  - `ready -> error` when the active slide cannot be refreshed
  - `error -> loading` on explicit retry
  - `unavailable -> loading` when upstream dependencies recover
  - `ready -> unavailable` when bridge or upstream services become unreachable

## ControllerManifest

- Purpose: Describes the active presentation returned by the Gaia bridge and sourced from Aither.
- Fields:
  - `courseId`: String
  - `presentationId`: String
  - `title`: String
  - `aspectRatio`: String (`16:9`)
  - `slideCount`: Int
  - `activeSlideIndex`: Int
  - `lastUpdated`: Date?
  - `slides`: [ControllerSlide]
- Validation Rules:
  - `aspectRatio` is fixed to `16:9` for this feature
  - `slideCount` must equal `slides.count`
  - `activeSlideIndex` must reference an existing slide
  - slide indexes must be unique and sequential

## ControllerSlide

- Purpose: Represents one slide plus its controller-side metadata.
- Fields:
  - `index`: Int
  - `fileName`: String
  - `htmlURL`: URL
  - `notes`: String
  - `notesSource`: Enum (`placeholder`, `upstream`)
  - `title`: String?
  - `contentState`: Enum (`pending`, `ready`, `failed`)
  - `etag`: String?
- Validation Rules:
  - `fileName` must end with `.html`
  - `htmlURL` must resolve through the Gaia bridge or the approved Aither view route
  - `notes` must always be present and may contain placeholder text until final notes are defined
  - `notesSource` must match whether the text came from Gaia fallback content or upstream notes data
  - `contentState == failed` requires the active load path to emit an error reason elsewhere in session state

## NavigationCommand

- Purpose: Represents a button-driven request to move the active slide.
- Fields:
  - `presentationId`: String
  - `command`: Enum (`previous`, `next`)
  - `fromIndex`: Int
  - `issuedAt`: Date
  - `requestId`: String
- Validation Rules:
  - `command` is restricted to `previous` and `next`
  - `fromIndex` must match the controller's current active slide at dispatch time
  - duplicate `requestId` values are invalid within the same session

## ViewportLayout

- Purpose: Encodes the UI layout invariants that keep the iPad controller aligned with the specification.
- Fields:
  - `maxWidthFraction`: Double (`0.75`)
  - `aspectRatio`: String (`16:9`)
  - `notesScrollEnabled`: Bool (`true`)
  - `navigationPlacement`: Enum (`belowViewport`)
  - `orientation`: Enum (`landscapeOnly`)
- Validation Rules:
  - `maxWidthFraction` must be greater than `0` and less than or equal to `0.75`
  - `notesScrollEnabled` is always `true` for this feature
  - `navigationPlacement` must remain beneath the slide viewport

## Relationships

- `ControllerSession` owns one `ControllerManifest` and tracks which `ControllerSlide` is active.
- `ControllerManifest` contains an ordered collection of `ControllerSlide` records.
- `NavigationCommand` is validated against `ControllerSession.activeSlideIndex` and updates `ControllerManifest.activeSlideIndex` when accepted.
- `ViewportLayout` constrains how the active `ControllerSlide` and notes are rendered in the iPad shell.