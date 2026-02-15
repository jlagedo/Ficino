# Genius + MusicKit Preprocessing: Schemas, Samples & Extraction Strategies

## 1. Raw API Schemas

### 1.1 MusicKit Song Attributes

Source: `MusicCatalogResourceRequest<Song>` or REST `/v1/catalog/{storefront}/songs/{id}`

```
Song {
  // --- Identity ---
  id:                  String          // "1544326470"
  title:               String          // "Me, Myself & I"
  artistName:          String          // "G-Eazy & Bebe Rexha"
  albumTitle:          String?         // "When It's Dark Out (Deluxe Edition)"
  composerName:        String?         // "Kai Engelmann, Phillip Herwig, ..."
  isrc:                String?         // "USRC11502210"
  
  // --- Temporal ---
  releaseDate:         String?         // "2015-10-30"
  durationInMillis:    Int?            // 251465
  
  // --- Classification ---
  genreNames:          [String]        // ["Hip-Hop/Rap", "Music"]
  contentRating:       String?         // "explicit"
  
  // --- Editorial (YOUR PRIMARY VALUE SOURCE) ---
  editorialNotes: {
    standard:          String?         // Long-form Apple editor prose (can be 500+ chars)
    short:             String?         // 1-2 sentence summary
  }
  
  // --- Audio ---
  audioVariants:       [AudioVariant]? // [.dolbyAtmos, .lossless]
  isAppleDigitalMaster: Bool?
  hasLyrics:           Bool
  
  // --- Playback ---
  trackNumber:         Int?
  discNumber:          Int?
  playParams:          PlayParams?
  
  // --- User-specific (requires user token) ---
  playCount:           Int?
  lastPlayedDate:      Date?
  libraryAddedDate:    Date?
}
```

**Sample editorialNotes.standard** (Smashing Pumpkins - Siamese Dream):
> "Their debut album, Gish, established Smashing Pumpkins as one of the most
> vital bands to emerge from the Chicago alt-rock scene, but Siamese Dream
> made them superstars..."

**What's useful:** editorialNotes, composerName, genreNames, releaseDate, audioVariants
**What's noise:** artwork colors, preview URLs, playParams, all imagery URLs

### 1.2 MusicKit Album Attributes (via `include[songs]=albums` relationship)

```
Album {
  name:                String          // "Siamese Dream (Remastered)"
  artistName:          String
  releaseDate:         String?         // "1993-07-26"
  recordLabel:         String?         // "Virgin Records"
  copyright:           String?         // "℗ 2011 Virgin Records America, Inc."
  genreNames:          [String]        // ["Rock", "Alternative", "Grunge", ...]
  trackCount:          Int
  isSingle:            Bool
  editorialNotes: {
    standard:          String?         // Often richer than song-level notes
    short:             String?
  }
}
```

**What's useful:** recordLabel, editorialNotes (album-level often has more backstory), copyright (gives original vs remaster year)
**What's noise:** artwork, playParams, isComplete

### 1.3 Genius `/songs/{id}` Response (via `?text_format=plain`)

```
Song {
  // --- Identity ---
  id:                  Int             // 4176
  title:               String          // "Work It"
  full_title:          String          // "Work It by Missy Elliott"
  url:                 String          // genius.com page URL
  path:                String          // "/Missy-elliott-work-it-lyrics"
  
  // --- Description (YOUR RICHEST CONTENT SOURCE) ---
  description: {
    plain:             String          // Editor/community written backstory prose
  }                                    // Can be 1000+ chars for popular songs
  
  // --- Stats ---
  stats: {
    pageviews:         Int             // 1205121
    hot:               Bool
    unreviewed_annotations: Int
  }
  annotation_count:    Int             // 32
  pyongs_count:        Int?            // 39 (Genius "likes")
  
  // --- Credits ---
  primary_artist: {
    id:                Int
    name:              String
    url:               String
  }
  featured_artists:    [Artist]
  producer_artists:    [Artist]        // KEY: actual producers
  writer_artists:      [Artist]        // KEY: actual songwriters
  
  // --- Relationships ---
  song_relationships:  [{              // samples, sampled_by, covers, remixes, etc.
    type:              String          // "samples", "sampled_in", "cover_of", etc.
    songs:             [Song]
  }]
  
  // --- Media ---
  media:               [{              // YouTube links, Spotify, SoundCloud
    provider:          String          // "youtube", "spotify"
    url:               String
    type:              String          // "video", "audio"
  }]
  
  // --- Album ---
  album: {
    id:                Int
    name:              String
    url:               String
    full_title:        String
  }
  
  // --- Metadata ---
  release_date:        String?         // "2002-05-14"
  release_date_for_display: String?    // "May 14, 2002"
  recording_location:  String?         // "Larrabee Studios, North Hollywood"
  
  // --- Custom Performances (extended credits) ---
  custom_performances: [{              // Additional roles: mixing, mastering, etc.
    label:             String          // "Mixing Engineer", "Guitar", "Bass"
    artists:           [Artist]
  }]
}
```

### 1.4 Genius `/referents?song_id={id}` (Annotations)

```
Referent {
  id:                  Int
  fragment:            String          // The lyric line being annotated
  annotations: [{
    id:                Int
    body: {
      plain:           String          // THE GOLD: community-written explanations,
    }                                  // interview quotes, production details
    votes_total:       Int             // Quality signal
    verified:          Bool            // Artist-verified annotation
    authors: [{
      name:            String
      user_id:         Int
    }]
    state:             String          // "accepted" = reviewed
  }]
}
```

---

## 2. Field Value Map: What Goes Where

| Information Type           | MusicKit Source            | Genius Source                           |
|---------------------------|----------------------------|-----------------------------------------|
| Song identity             | title, artistName          | title, primary_artist                   |
| Producers                 | —                          | producer_artists, custom_performances   |
| Songwriters               | composerName               | writer_artists                          |
| Samples used              | —                          | song_relationships[type="samples"]      |
| Sampled by                | —                          | song_relationships[type="sampled_in"]   |
| Recording studio          | —                          | recording_location                      |
| Backstory / context       | editorialNotes.standard    | description.plain                       |
| Deep trivia / quotes      | —                          | referent annotations (body.plain)       |
| Album context             | album.editorialNotes       | album.full_title                        |
| Record label              | album.recordLabel          | —                                       |
| Genre                     | genreNames                 | —                                       |
| Audio quality             | audioVariants, isAppleDigitalMaster | —                            |
| Release date              | releaseDate                | release_date_for_display                |
| Popularity signal         | —                          | stats.pageviews, annotation_count       |
| Verified artist insight   | —                          | annotations where verified=true         |

---

## 3. Extraction Strategies

### Strategy 1: Structured Fact Extraction Pipeline

Run server-side at ingestion time. For each song:

```
INPUT: MusicKit song + album -> Genius song + top annotations
OUTPUT: CompactSongFacts JSON (target: < 800 tokens)
```

**Step 1: Fetch & Merge**
```
musickit_song  = MusicKit.catalog.song(id, properties: [.editorialNotes, .albums])
genius_song    = Genius.song(id, text_format: "plain")
genius_refs    = Genius.referents(song_id: genius_song.id, per_page: 20, text_format: "plain")
```

**Step 2: Deduplicate**
MusicKit and Genius will overlap on: title, artist, release date, album name.
Keep MusicKit as canonical for these. Genius adds everything else.

**Step 3: Rank Annotations**
```
scored_annotations = genius_refs
  .flatMap { $0.annotations }
  .filter { $0.state == "accepted" }
  .sorted { 
    score($0) > score($1) 
  }
  .prefix(5)

func score(_ a: Annotation) -> Int {
  var s = a.votes_total
  if a.verified { s += 1000 }            // Artist-verified = top priority
  if a.body.plain.count > 50 { s += 10 } // Substance over one-liners
  if a.body.plain.contains(keywords) { s += 20 } // Boost production/interview content
  return s
}

// keywords: ["studio", "interview", "said", "inspired", "sample", 
//            "produced", "recorded", "originally", "reference", 
//            "meaning", "story behind"]
```

**Step 4: Extract Facts by Category**

```swift
struct CompactSongFacts: Codable {
    let production: ProductionFacts?
    let backstory: String?               // Max 200 chars
    let samples: [SampleRef]             // Max 3
    let credits: CreditsFacts
    let trivia: [String]                 // Max 3 facts, each max 100 chars
    let editorial: String?               // Max 200 chars
}

struct ProductionFacts: Codable {
    let producers: [String]              // From genius.producer_artists
    let studio: String?                  // From genius.recording_location
    let mixEngineers: [String]?          // From genius.custom_performances
}

struct SampleRef: Codable {
    let title: String
    let artist: String
    let direction: String                // "samples" or "sampled_by"
}

struct CreditsFacts: Codable {
    let writers: [String]                // Merge musickit.composerName + genius.writer_artists
    let featuredArtists: [String]
}
```

### Strategy 2: Annotation Content Classifier

Not all annotations are interesting. Classify before including:

| Category       | Signal Words                                          | Value |
|---------------|-------------------------------------------------------|-------|
| Production    | studio, recorded, mixed, mastered, Pro Tools, analog  | HIGH  |
| Interview     | said, interview, told, explained, according to        | HIGH  |
| Sample/ref    | sample, interpolat, reference, allusion, callback     | HIGH  |
| Personal      | inspired by, wrote about, dedicated, based on         | HIGH  |
| Chart/award   | #1, Billboard, Grammy, platinum, certified            | MED   |
| Music video   | video, directed, filmed, visual                       | MED   |
| Lyric meaning | means, refers to, metaphor, symboliz                  | LOW   |
| Generic       | this line, the artist, here we see                    | DROP  |

Implementation: simple keyword scoring. No ML needed for this.

```python
HIGH_SIGNAL = ["studio", "recorded", "said in", "interview", "sample", 
               "inspired", "originally", "produced by", "wrote this"]

def classify_annotation(text: str) -> tuple[str, int]:
    text_lower = text.lower()
    score = 0
    category = "generic"
    
    for kw in HIGH_SIGNAL:
        if kw in text_lower:
            score += 10
            category = "high_value"
    
    if len(text) < 30:
        score -= 20  # Penalize one-liners
    
    return category, score
```

### Strategy 3: Compression for 4K Context Window

Target token budget per section when feeding to Apple on-device model:

```
System prompt + instructions:  ~150 tokens
Song identity (title/artist):   ~30 tokens
Production facts:               ~80 tokens
Backstory:                     ~120 tokens  
Top 2-3 annotations:          ~200 tokens
Credits summary:                ~50 tokens
-------------------------------------------
TOTAL INPUT:                   ~630 tokens
Available for output:        ~1000 tokens
Safety margin:               ~2400 tokens
```

Compression rules:
- Strip all Genius HTML, markdown, URLs
- Replace artist full objects with just names
- Collapse custom_performances into "Role: Name" strings  
- Truncate any single annotation to 280 chars (tweet-length)
- Deduplicate writer names between MusicKit composerName and Genius writer_artists
- Drop annotations with votes_total < 3 (low quality signal)
- Drop song_relationships beyond samples/sampled_in (covers, remixes less interesting)
- For editorialNotes: if both song-level and album-level exist, prefer song-level. 
  Fall back to album-level only if song-level is null or < 50 chars.

### Strategy 4: Cache-First Architecture

Not every song needs real-time processing.

```
[Now Playing detected via MusicKit]
        |
        v
[Local Cache: SQLite / Core Data]
   |                    |
   | HIT                | MISS
   v                    v
[Return cached       [Background fetch:]
 CompactSongFacts]    1. Genius API search by title+artist
                      2. Genius /songs/{id}?text_format=plain
                      3. Genius /referents?song_id={id}
                      4. Run extraction pipeline
                      5. Store CompactSongFacts
                      6. Return to UI
```

Cache key: `{isrc}` (from MusicKit) or `{title}_{artistName}` normalized.
ISRC is globally unique per recording — best key if available.

### Strategy 5: Genius-to-MusicKit Matching

The hardest part: matching the currently playing MusicKit song to a Genius song.

```
Input: MusicKit Song (title: "Bohemian Rhapsody", artistName: "Queen")

Step 1: Search Genius
  GET /search?q=Bohemian+Rhapsody+Queen
  
Step 2: Score candidates
  for each hit in results:
    title_sim  = normalized_similarity(hit.title, musickit.title)
    artist_sim = normalized_similarity(hit.primary_artist.name, musickit.artistName)
    score = (title_sim * 0.6) + (artist_sim * 0.4)
  
Step 3: Accept if score > 0.85, else mark as unmatched

Normalization:
  - lowercase
  - strip parentheticals: "(Remastered)", "(feat. X)", "(Deluxe)"
  - strip punctuation
  - collapse whitespace
```

Edge cases to handle:
- Featured artists in title vs separate field
- "Remastered" / "Deluxe" / year suffixes
- Non-Latin characters
- Live versions vs studio versions

---

## 4. Sample Claude Batch Prompt for Training Data Generation

```json
{
  "system": "You are a music journalist writing concise, interesting facts about songs. Given raw metadata from MusicKit and Genius APIs, produce exactly 3-5 fascinating facts. Each fact must be: self-contained (understandable without context), 1-2 sentences max, focused on production, backstory, cultural impact, or artist intent. Never invent information not present in the input. Output as JSON array of strings.",
  
  "user": "MUSICKIT DATA:\nTitle: Bohemian Rhapsody\nArtist: Queen\nAlbum: A Night at the Opera\nRelease: 1975-10-31\nLabel: EMI\nComposers: Freddie Mercury\nGenre: Rock\n\nGENIUS DESCRIPTION:\nBohemian Rhapsody is the lead single from Queen's fourth studio album. The song defied conventional structure with its operatic midsection. Mercury spent years developing the concept and the recording took three weeks at Rockfield Studios in Wales.\n\nTOP GENIUS ANNOTATIONS:\n1. [verified, 847 votes] Mercury reportedly told the band 'don't worry, I'll teach you' when they questioned the operatic section.\n2. [342 votes] The recording used 180 vocal overdubs for the opera section, pushing the tape to its physical limits.\n3. [201 votes] Originally titled 'The Cowboy Song' in early demo stages.\n\nGENIUS CREDITS:\nProducers: Roy Thomas Baker, Queen\nRecording: Rockfield Studios, Monmouthshire, Wales\nMixing: Mike Stone"
}
```

Expected output:
```json
[
  "The recording session at Rockfield Studios in Wales lasted three weeks, with the operatic section requiring 180 vocal overdubs that pushed the physical tape to its limits.",
  "Freddie Mercury had been developing the concept for years, and when bandmates questioned the operatic section, he reportedly told them 'don't worry, I'll teach you.'",
  "The song was originally titled 'The Cowboy Song' in its early demo stages before evolving into the genre-defying six-minute epic.",
  "Produced by Roy Thomas Baker alongside the band themselves, the unconventional structure — ballad, opera, hard rock — broke every radio formatting rule of the era."
]
```

---

## 5. Data Quality Tiers

Not all songs will have equal coverage. Plan for graceful degradation:

| Tier | Genius Data Available | MusicKit Data | Strategy |
|------|----------------------|---------------|----------|
| A    | Description + 5+ annotations + full credits | editorialNotes present | Full extraction pipeline. Rich output. |
| B    | Description + sparse annotations | editorialNotes present | Merge both sources. Decent output. |
| C    | Description only, no annotations | editorialNotes present | Rely on description + editorial. Thinner output. |
| D    | No Genius match found | editorialNotes present | MusicKit editorial only. Minimal facts. |
| E    | No Genius match found | No editorialNotes | Credits + genre + release date only. Consider skipping or showing just metadata. |

Popularity signal from Genius (`stats.pageviews`) predicts tier:
- \> 100K views → likely Tier A
- 10K-100K → likely Tier B/C
- < 10K → likely Tier C/D
