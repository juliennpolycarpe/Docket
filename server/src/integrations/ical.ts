// Minimal iCalendar (.ics, RFC 5545) reader: just the VEVENT fields Docket uses.

export interface IcsEvent {
  uid: string;
  summary: string;
  description: string | null;
  location: string | null;
  url: string | null;
  start: Date;
  end: Date | null;
  allDay: boolean;
}

interface Property {
  name: string;
  params: Record<string, string>;
  value: string;
}

// Long lines are folded onto continuation lines that start with a space or tab.
function unfold(text: string): string[] {
  return text.replace(/\r\n|\r/g, "\n").replace(/\n[ \t]/g, "").split("\n");
}

function parseLine(line: string): Property | null {
  // The name and parameters end at the first colon that isn't inside quotes.
  let inQuotes = false;
  let colon = -1;
  for (let i = 0; i < line.length; i++) {
    if (line[i] === '"') inQuotes = !inQuotes;
    else if (line[i] === ":" && !inQuotes) {
      colon = i;
      break;
    }
  }
  if (colon < 0) return null;

  const [name, ...rawParams] = line.slice(0, colon).split(";");
  const params: Record<string, string> = {};
  for (const param of rawParams) {
    const eq = param.indexOf("=");
    if (eq > 0) params[param.slice(0, eq).toUpperCase()] = param.slice(eq + 1).replace(/^"|"$/g, "");
  }
  return { name: name.toUpperCase(), params, value: line.slice(colon + 1) };
}

function unescapeText(value: string): string {
  return value.replace(/\\([\\;,nN])/g, (_, ch: string) => (ch === "n" || ch === "N" ? "\n" : ch));
}

// How far ahead of UTC the time zone is at the given instant, in ms.
function zoneOffsetMs(utcMs: number, timeZone: string): number {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat("en-US", {
      timeZone,
      hourCycle: "h23",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    })
      .formatToParts(new Date(utcMs))
      .map((p) => [p.type, p.value]),
  );
  const asIfUtc = Date.UTC(+parts.year, +parts.month - 1, +parts.day, +parts.hour, +parts.minute, +parts.second);
  return asIfUtc - Math.floor(utcMs / 1000) * 1000;
}

function zonedToUtc(fields: number[], timeZone: string): Date {
  const [y, mo, d, h, mi, s] = fields;
  const wall = Date.UTC(y, mo - 1, d, h, mi, s);
  const first = wall - zoneOffsetMs(wall, timeZone);
  // A second pass gets the right offset when the guess lands across a daylight-saving change.
  return new Date(wall - zoneOffsetMs(first, timeZone));
}

/** Parses DATE / DATE-TIME values. Returns null if the value is malformed. */
export function parseIcsDate(value: string, params: Record<string, string> = {}): { date: Date; allDay: boolean } | null {
  const match = value.match(/^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$/);
  if (!match) return null;
  const [, y, mo, d, h, mi, s, utc] = match;

  if (h === undefined) {
    // All-day: there's no time zone to go on, so use noon UTC, which falls on
    // the same calendar date almost everywhere.
    return { date: new Date(Date.UTC(+y, +mo - 1, +d, 12)), allDay: true };
  }
  const fields = [+y, +mo, +d, +h, +mi, +s];
  if (!utc && params.TZID) {
    try {
      return { date: zonedToUtc(fields, params.TZID), allDay: false };
    } catch {
      // Unknown time zone name; fall through and treat it as UTC.
    }
  }
  return { date: new Date(Date.UTC(fields[0], fields[1] - 1, fields[2], fields[3], fields[4], fields[5])), allDay: false };
}

export function parseIcs(text: string): IcsEvent[] {
  const events: IcsEvent[] = [];
  let current: Map<string, Property> | null = null;
  let nestedDepth = 0; // inside VALARM etc. within an event

  for (const line of unfold(text)) {
    const prop = parseLine(line);
    if (!prop) continue;

    if (prop.name === "BEGIN") {
      if (prop.value.toUpperCase() === "VEVENT") current = new Map();
      else if (current) nestedDepth++;
      continue;
    }
    if (prop.name === "END") {
      if (current && nestedDepth > 0) {
        nestedDepth--;
      } else if (prop.value.toUpperCase() === "VEVENT" && current) {
        const event = toEvent(current);
        if (event) events.push(event);
        current = null;
      }
      continue;
    }
    if (current && nestedDepth === 0 && !current.has(prop.name)) current.set(prop.name, prop);
  }
  return events;
}

function toEvent(props: Map<string, Property>): IcsEvent | null {
  const uid = props.get("UID")?.value;
  const startProp = props.get("DTSTART");
  const start = startProp && parseIcsDate(startProp.value, startProp.params);
  if (!uid || !start) return null;

  const endProp = props.get("DTEND");
  const end = endProp ? parseIcsDate(endProp.value, endProp.params) : null;
  const text = (name: string) => {
    const value = props.get(name)?.value;
    return value ? unescapeText(value).trim() || null : null;
  };

  return {
    uid,
    summary: text("SUMMARY") ?? "Untitled",
    description: text("DESCRIPTION"),
    location: text("LOCATION"),
    url: props.get("URL")?.value.trim() || null,
    start: start.date,
    end: end?.date ?? null,
    allDay: start.allDay,
  };
}
