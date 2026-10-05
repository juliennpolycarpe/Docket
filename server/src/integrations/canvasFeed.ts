// Canvas calendar feed: the private link under Calendar > "Calendar Feed" in
// Canvas. It's an .ics file of the user's assignments (with due dates) and
// course events. Works without an API token, but doesn't say what's been submitted.

import { createHash } from "node:crypto";
import { isIP } from "node:net";
import { parseIcs, type IcsEvent } from "./ical.js";

export class CanvasFeedError extends Error {}

const MAX_FEED_CHARS = 20 * 1024 * 1024;

const HOW_TO_FIND =
  'In Canvas, open Calendar and click "Calendar Feed" at the bottom right, then copy the whole link.';

/** Accepts the link as Canvas shows it (https:// or webcal://) and returns it as https. */
export function normalizeFeedUrl(input: string): URL {
  let url: URL;
  try {
    url = new URL(input.trim().replace(/^webcal:\/\//i, "https://"));
  } catch {
    throw new CanvasFeedError(`That isn't a link. ${HOW_TO_FIND}`);
  }
  if (url.protocol !== "https:") throw new CanvasFeedError("The feed link should start with https:// or webcal://.");
  if (!/\/feeds\/calendars\/[^/]+\.ics$/i.test(url.pathname)) {
    throw new CanvasFeedError(`That isn't a Canvas calendar feed link. ${HOW_TO_FIND}`);
  }
  // The server fetches this link, so never let it point at the server's own network.
  const host = url.hostname.replace(/^\[|\]$/g, "").toLowerCase();
  if (isIP(host) || host === "localhost" || /\.(localhost|local|internal)$/.test(host)) {
    throw new CanvasFeedError("That link doesn't point to a Canvas site.");
  }
  return url;
}

/** Stable id for the feed that doesn't reveal the secret link itself. */
export function feedId(url: URL): string {
  return createHash("sha256").update(url.href).digest("hex").slice(0, 24);
}

export async function fetchFeed(url: URL): Promise<IcsEvent[]> {
  let response: Response;
  try {
    response = await fetch(url, { headers: { Accept: "text/calendar" }, signal: AbortSignal.timeout(20_000) });
  } catch {
    throw new CanvasFeedError("Couldn't reach Canvas. Check the link and your connection.");
  }
  if ([401, 403, 404].includes(response.status)) {
    throw new CanvasFeedError(`Canvas didn't recognize that feed link. It may have been reset. ${HOW_TO_FIND}`);
  }
  if (!response.ok) throw new CanvasFeedError(`Canvas returned an error (HTTP ${response.status}).`);

  const text = await response.text();
  if (text.length > MAX_FEED_CHARS) throw new CanvasFeedError("That calendar is too large to import.");
  if (!text.includes("BEGIN:VCALENDAR")) throw new CanvasFeedError(`That link didn't return a calendar. ${HOW_TO_FIND}`);
  return parseIcs(text);
}

export interface FeedTask {
  external_id: string;
  title: string;
  course_name: string | null;
  due_at: string;
  url: string | null;
}

export interface FeedEvent {
  external_id: string;
  title: string;
  location: string | null;
  starts_at: string;
  ends_at: string | null;
  all_day: boolean;
  url: string | null;
}

export type FeedItem = { kind: "task"; task: FeedTask } | { kind: "event"; event: FeedEvent };

/** Canvas ends titles with the course: "Project 3 [CS 3013 - Operating Systems]". */
export function splitCourse(summary: string): { title: string; course: string | null } {
  const match = summary.match(/^(.*\S)\s*\[([^[\]]+)\]$/);
  return match ? { title: match[1], course: match[2].trim() } : { title: summary, course: null };
}

/** Assignments (UIDs like "event-assignment-123") become tasks; everything else is an event. */
export function feedEventToItem(event: IcsEvent): FeedItem {
  const { title, course } = splitCourse(event.summary);

  if (/assignment/i.test(event.uid)) {
    const id = event.uid.match(/(\d+)$/)?.[1];
    return {
      kind: "task",
      task: {
        // Same id format as the API sync, in case an account later switches to a token.
        external_id: id ? `assignment:${id}` : event.uid,
        title,
        course_name: course,
        due_at: event.start.toISOString(),
        url: event.url,
      },
    };
  }

  const end = event.end && !event.allDay && event.end.getTime() > event.start.getTime() ? event.end : null;
  return {
    kind: "event",
    event: {
      external_id: event.uid,
      title: course ? `${title} (${course})` : title,
      location: event.location,
      starts_at: event.start.toISOString(),
      ends_at: end?.toISOString() ?? null,
      all_day: event.allDay,
      url: event.url,
    },
  };
}
