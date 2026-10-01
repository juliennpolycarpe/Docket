import assert from "node:assert/strict";
import { test } from "node:test";
import { nextPageUrl, normalizeBaseUrl, plannerItemToTask, type PlannerItem } from "./canvas.js";

const base = "https://canvas.example.edu";

test("normalizeBaseUrl accepts bare hosts and strips paths", () => {
  assert.equal(normalizeBaseUrl("canvas.example.edu"), base);
  assert.equal(normalizeBaseUrl("  https://canvas.example.edu/courses/42  "), base);
});

test("normalizeBaseUrl rejects plain http", () => {
  assert.throws(() => normalizeBaseUrl("http://canvas.example.edu"));
});

test("maps an assignment", () => {
  const item: PlannerItem = {
    plannable_id: 555,
    plannable_type: "assignment",
    plannable_date: "2026-10-03T03:59:00Z",
    plannable: { title: "Project 3: Threads", due_at: "2026-10-03T03:59:00Z" },
    context_name: "CS 3013",
    html_url: "/courses/12/assignments/555",
    submissions: { submitted: false },
    planner_override: null,
  };
  assert.deepEqual(plannerItemToTask(item, base), {
    external_id: "assignment:555",
    title: "Project 3: Threads",
    course_name: "CS 3013",
    due_at: "2026-10-03T03:59:00Z",
    url: "https://canvas.example.edu/courses/12/assignments/555",
    submitted: false,
  });
});

test("submitted or marked-complete items count as submitted", () => {
  const submitted: PlannerItem = { plannable_id: 1, plannable_type: "quiz", plannable: { title: "Quiz" }, submissions: { submitted: true } };
  const markedDone: PlannerItem = { plannable_id: 2, plannable_type: "planner_note", plannable: { title: "Note" }, submissions: false, planner_override: { marked_complete: true } };
  assert.equal(plannerItemToTask(submitted, base)?.submitted, true);
  assert.equal(plannerItemToTask(markedDone, base)?.submitted, true);
});

test("skips announcements and calendar events", () => {
  for (const type of ["announcement", "calendar_event"]) {
    assert.equal(plannerItemToTask({ plannable_id: 1, plannable_type: type, plannable: { title: "x" } }, base), null);
  }
});

test("nextPageUrl finds rel=next among other links", () => {
  const header =
    '<https://canvas.example.edu/api/v1/planner/items?page=1>; rel="current",' +
    '<https://canvas.example.edu/api/v1/planner/items?page=2>; rel="next",' +
    '<https://canvas.example.edu/api/v1/planner/items?page=1>; rel="first"';
  assert.equal(nextPageUrl(header), "https://canvas.example.edu/api/v1/planner/items?page=2");
  assert.equal(nextPageUrl('<https://canvas.example.edu/x?page=1>; rel="first"'), null);
  assert.equal(nextPageUrl(null), null);
});
