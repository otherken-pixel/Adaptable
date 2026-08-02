/**
 * Optional Slack/Discord-style webhook for content reports.
 * Set REPORT_WEBHOOK_URL in Vercel env to enable.
 */

export const config = { runtime: "edge" };

export default async function handler(request: Request): Promise<Response> {
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  const webhook = process.env.REPORT_WEBHOOK_URL;
  if (!webhook) {
    return new Response(JSON.stringify({ ok: true, skipped: true }), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  }

  try {
    const body = await request.json();
    const text = `Adaptable report: ${body.targetType} ${body.targetId} — ${body.reason} (by ${body.reporterId})`;
    await fetch(webhook, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ text, content: text, ...body }),
    });
    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ ok: false }), {
      status: 500,
      headers: { "content-type": "application/json" },
    });
  }
}
