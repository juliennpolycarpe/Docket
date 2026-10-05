import assert from "node:assert/strict";
import { test } from "node:test";
import { feedEventToItem, feedId, normalizeFeedUrl, splitCourse } from "./canvasFeed.js";
import type { IcsEvent } from "./ical.js";

const feed = "https://canvas.example.edu/feeds/calendars/user_AbC123secret.ics";

test("accepts https and webcal feed links", () => {
  assert.equal(normalizeFeedUrl(feed).href, feed);
  assert.equal(normalizeFeedUrl("  webcal://canvas.example.edu/feeds/calendars/user_AbC123secret.ics ").href, feed);
});

test("rejects links that aren't Canvas feeds or point at private hosts", () => {
  assert.throws(() => normalizeFeedUrl("not a link"));
  assert.throws(() => normalizeFeedUrl("http://canvas.example.edu/feeds/calendars/user_x.ics"));
  assert.throws(() => normalizeFeedUrl("https://canvas.example.edu/courses/12"));
  assert.throws(() => normalizeFeedUrl("https://localhost/feeds/calendars/user_x.ics"));
  assert.throws(() => normalizeFeedUrl("https://10.0.0.5/feeds/calendars/user_x.ics"));
  assert.throws(() => normalizeFeedUrl("https://[::1]/feeds/calendars/user_x.ics"));
});

test("feedId is stable and doesn't contain the secret", () => {
  const id = feedId(new URL(feed));
  assert.equal(id, feedId(new URL(feed)));
  assert.ok(!id.includes("AbC123secret"));
});

test("splits the course off the end of the title", () => {
  assert.deepEqual(splitCourse("Project 3 [CS 3013 - Operating Systems]"), { title: "Project 3", course: "CS 3013 - Operating Systems" });
  assert.deepEqual(splitCourse("Office hours"), { title: "Office hours", course: null });
});

const base: IcsEvent = {
  uid: "",
  summary: "",
  description: null,
  location: null,
  url: null,
  start: new Date("2026-10-06T03:59:00Z"),
  end: null,
  allDay: false,
};

test("assignments become tasks", () => {
  const item = feedEventToItem({ ...base, uid: "event-assignment-555", summary: "Project 3 [CS 3013]", url: "https://x/a/555" });
  assert.deepEqual(item, {
    kind: "task",
    task: {
      external_id: "assignment:555",
      title: "Project 3",
      course_name: "CS 3013",
      due_at: "2026-10-06T03:59:00.000Z",
      url: "https://x/a/555",
    },
  });
});

test("other calendar entries become events", () => {
  const item = feedEventToItem({
    ...base,
    uid: "event-calendar-event-77",
    summary: "Exam review [CS 3013]",
    location: "Fuller 320",
    end: new Date("2026-10-06T05:00:00Z"),
  });
  assert.equal(item.kind, "event");
  if (item.kind !== "event") return;
  assert.equal(item.event.title, "Exam review (CS 3013)");
  assert.equal(item.event.location, "Fuller 320");
  assert.equal(item.event.ends_at, "2026-10-06T05:00:00.000Z");
});

test("all-day events and zero-length events have no end", () => {
  const allDay = feedEventToItem({ ...base, uid: "e1", summary: "No class", allDay: true, end: new Date("2026-10-07T12:00:00Z") });
  const instant = feedEventToItem({ ...base, uid: "e2", summary: "Reminder", end: base.start });
  assert.ok(allDay.kind === "event" && allDay.event.ends_at === null && allDay.event.all_day);
  assert.ok(instant.kind === "event" && instant.event.ends_at === null);
});
