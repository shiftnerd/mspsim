# Notes: content-forum (R28, three more LabRat Nerds regulars)

Three more forum regulars after WSUS_Walt, each with art (both facings, 135-frame anim files built with `ONLY`), a four-option
card (`Expo.FORUM`), a `Nerds.POSTERS` title (REGULAR), one post in an open thread and a place to stand. Test: `tests/forum_people.gd`
(the `more` table at the end: sheets, placement off the doors and the other people, the card pays two skills + karma + a social point,
the first answer and the thread option give +4 XP / +3 karma, title and post exist). All wording is a first draft (strings workflow:
the `# Expo > FORUM` section was deleted and re-synced after each card, because the cards are inserted before Dot).

| Handle | File | Look | Where | Thread |
|---|---|---|---|---|
| PaperJam_Pat | `expo_pat` (`make_fem.lua`, style `long`) | plum long hair, cyan cardigan over a yellow blouse (toner colours), brown trousers, teal shoes, no glasses | resort_hall x 250 (right of the priest, between the doors at 213 and 283) | Print spooler keeps dying on 2008 R2 |
| SpinUp_Vic | `expo_vic` (`make_men.lua`, donor `office_dan`, `tufts`) | bleached spiky hair, violet long-sleeve shirt with a logo badge, light jeans, orange sneakers | vendor_hall x 183 (between the booth at 159 and Pip at 205) | Is it OK to host the RMM server in the cloud? |
| PatchPanel_Gus | `expo_gus` (`make_men.lua`, new option `badges`) | rust-red hair, olive polo, black trousers, a grey-blue lanyard with a cascade of four badges (white / yellow / green / orange), no stubble | resort_lobby x 66 (between the door at 37 and the check-in desk at 100) | VLANs for voice and data on a cheap switch |

Cards (effects): Pat toner +4 servers, jam +3 customer, upvote her spooler answer +3 karma, test page +1 social. Vic consolidating +4 servers,
snapshots +3 security, upvote "just spin up a VM" +3 karma, tell him it is a real box +1 social. Gus patch panel +4 networking, his badges +3 customer,
upvote his cabling tip +3 karma, count his badges +1 social. Free Play options keep a `text_free` without the promise of karma / social.

## Decisions made
- The handles avoid real vendor names (the canon test); "VM" is generic. The speaker "CARL WEBB" of the `virt` session already exists, so the cable
  person is Gus.
- `make_men.lua` got a `badges` option (the lanyard of `make_fem.lua` plus four overlapping badges that share edges) on the Collar layer.
- New cards are inserted before Dot, so the Expo.FORUM strings section is re-synced each time (no key was edited by hand).
- Not seen in a game screenshot unless the report says so: placement was checked by test against the crowd x positions and doors.
