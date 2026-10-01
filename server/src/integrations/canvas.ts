// Canvas LMS API: https://canvas.instructure.com/doc/api/
//
// Docket connects with a personal access token the user creates in Canvas
// under Account > Settings > "+ New Access Token". Assignments come from the
// planner endpoint, which is what Canvas's own To Do list uses, so quizzes and
// graded discussions show up too.

export class CanvasError extends Error {
  constructor(message: string, readonly status?: number) {
    super(message);
  }
}

export interface CanvasProfile {
  id: number;
  name: string;
}

export interface PlannerItem {
  plannable_id: number | string;
  plannable_type: string;
  plannable_date?: string | null;
  plannable: {
    title?: string;
    name?: string;
    due_at?: string | null;
    todo_date?: string | null;
  };
  context_name?: string | null;
  html_url?: string | null;
  submissions?: false | { submitted?: boolean };
  planner_override?: { marked_complete?: boolean } | null;
}

export interface CanvasTask {
  external_id: string;
  title: string;
  course_name: string | null;
  due_at: string | null;
  url: string | null;
  submitted: boolean;
}

// Planner item types that belong in To Do. Announcements and calendar events are skipped.
const TASK_TYPES = new Set(["assignment", "quiz", "discussion_topic", "wiki_page", "planner_note", "assessment_request"]);

// Accepts "canvas.wpi.edu", "https://canvas.wpi.edu/courses/123", etc. and
// returns just the origin. Only https is allowed, since the token is sent with every request.
export function normalizeBaseUrl(input: string): string {
  const trimmed = input.trim();
  const url = new URL(/^[a-z]+:\/\//i.test(trimmed) ? trimmed : `https://${trimmed}`);
  if (url.protocol !== "https:") throw new CanvasError("Canvas address must start with https://");
  return url.origin;
}

export function plannerItemToTask(item: PlannerItem, baseUrl: string): CanvasTask | null {
  if (!TASK_TYPES.has(item.plannable_type)) return null;
  const { plannable } = item;
  return {
    external_id: `${item.plannable_type}:${item.plannable_id}`,
    title: plannable.title ?? plannable.name ?? "Untitled",
    course_name: item.context_name ?? null,
    due_at: plannable.due_at ?? plannable.todo_date ?? item.plannable_date ?? null,
    url: item.html_url ? new URL(item.html_url, baseUrl).toString() : null,
    submitted: Boolean((item.submissions && item.submissions.submitted) || item.planner_override?.marked_complete),
  };
}

// Canvas paginates with a Link header: <https://...&page=2>; rel="next"
export function nextPageUrl(linkHeader: string | null): string | null {
  if (!linkHeader) return null;
  for (const part of linkHeader.split(",")) {
    const match = part.match(/<([^>]+)>\s*;\s*rel="next"/);
    if (match) return match[1];
  }
  return null;
}

async function canvasGet(url: string, token: string): Promise<Response> {
  let response: Response;
  try {
    response = await fetch(url, { headers: { Authorization: `Bearer ${token}`, Accept: "application/json" } });
  } catch {
    throw new CanvasError("Couldn't reach Canvas. Check the address and your connection.");
  }
  if (response.status === 401) {
    throw new CanvasError("Canvas rejected the access token. It may be wrong, expired, or revoked.", 401);
  }
  if (!response.ok) {
    throw new CanvasError(`Canvas returned an error (HTTP ${response.status}).`, response.status);
  }
  return response;
}

export async function getProfile(baseUrl: string, token: string): Promise<CanvasProfile> {
  const response = await canvasGet(`${baseUrl}/api/v1/users/self`, token);
  return (await response.json()) as CanvasProfile;
}

export async function getPlannerItems(baseUrl: string, token: string, start: Date, end: Date): Promise<PlannerItem[]> {
  const params = new URLSearchParams({
    start_date: start.toISOString(),
    end_date: end.toISOString(),
    per_page: "100",
  });
  const items: PlannerItem[] = [];
  let url: string | null = `${baseUrl}/api/v1/planner/items?${params}`;
  while (url) {
    const response = await canvasGet(url, token);
    items.push(...((await response.json()) as PlannerItem[]));
    url = nextPageUrl(response.headers.get("link"));
    // Never send the token anywhere but the user's Canvas instance.
    if (url && new URL(url).origin !== baseUrl) {
      throw new CanvasError("Canvas returned a page link to a different site; stopping.");
    }
  }
  return items;
}
