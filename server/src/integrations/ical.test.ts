import assert from "node:assert/strict";
import { test } from "node:test";
import { parseIcs, parseIcsDate } from "./ical.js";

const sample = [
  "BEGIN:VCALENDAR",
  "VERSION:2.0",
  "PRODID:-//Instructure//Canvas//EN",
  "BEGIN:VEVENT",
  "DTSTART:20261006T035900Z",
  "DTEND:20261006T035900Z",
  "UID:event-assignment-555",
  "SUMMARY:Project 3: Threads\\, locks [CS 3013 - Operating Sy",
  " stems]",
  "URL;VALUE=URI:https://canvas.example.edu/courses/12/assignments/555",
  "BEGIN:VALARM",
  "SUMMARY:Ignore me",
  "END:VALARM",
  "END:VEVENT",
  "BEGIN:VEVENT",
  "DTSTART;VALUE=DATE:20261010",
  "DTEND;VALUE=DATE:20261011",
  "UID:event-calendar-event-77",
  "SUMMARY:No class",
  "DESCRIPTION:Line one\\nLine two",
  "END:VEVENT",
  "BEGIN:VEVENT",
  "SUMMARY:Missing start, skipped",
  "UID:broken",
  "END:VEVENT",
  "END:VCALENDAR",
].join("\r\n");

test("parses events, unfolding long lines and unescaping text", () => {
  const events = parseIcs(sample);
  assert.equal(events.length, 2);

  const [assignment, holiday] = events;
  assert.equal(assignment.uid, "event-assignment-555");
  assert.equal(assignment.summary, "Project 3: Threads, locks [CS 3013 - Operating Systems]");
  assert.equal(assignment.start.toISOString(), "2026-10-06T03:59:00.000Z");
  assert.equal(assignment.url, "https://canvas.example.edu/courses/12/assignments/555");
  assert.equal(assignment.allDay, false);

  assert.equal(holiday.allDay, true);
  assert.equal(holiday.description, "Line one\nLine two");
});

test("VALARM properties don't leak into the event", () => {
  assert.notEqual(parseIcs(sample)[0].summary, "Ignore me");
});

test("converts times with a time zone to UTC, including across daylight saving", () => {
  // 11:59 PM in New York is 03:59 UTC the next day in October (EDT, UTC-4)...
  assert.equal(parseIcsDate("20261005T235900", { TZID: "America/New_York" })?.date.toISOString(), "2026-10-06T03:59:00.000Z");
  // ...and 04:59 UTC in December (EST, UTC-5).
  assert.equal(parseIcsDate("20261205T235900", { TZID: "America/New_York" })?.date.toISOString(), "2026-12-06T04:59:00.000Z");
});

test("unknown time zones and floating times are treated as UTC", () => {
  assert.equal(parseIcsDate("20261005T120000", { TZID: "Not/AZone" })?.date.toISOString(), "2026-10-05T12:00:00.000Z");
  assert.equal(parseIcsDate("20261005T120000")?.date.toISOString(), "2026-10-05T12:00:00.000Z");
  assert.equal(parseIcsDate("garbage"), null);
});
