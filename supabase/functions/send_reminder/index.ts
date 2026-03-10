import "jsr:@supabase/functions-js/edge-runtime.d.ts";

Deno.serve(async (_req) => {
  const supabaseClient = createServiceClient();

  const now = new Date();
  const in1h = new Date(now.getTime() + 60 * 60 * 1000);
  const in24h = new Date(now.getTime() + 24 * 60 * 60 * 1000);

  const nowIso = now.toISOString();
  const in1hIso = in1h.toISOString();
  const in24hIso = in24h.toISOString();

  const { data: upcoming, error } = await supabaseClient
    .from("reservations")
    .select("id,user_id,date,start_time,status")
    .eq("status", "APPROVED");

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
    });
  }

  if (!upcoming) {
    return new Response(JSON.stringify({ count: 0 }));
  }

  const toNotify: { user_id: string; title: string; message: string }[] = [];

  for (const r of upcoming) {
    const dateStr = r.date as string;
    const startTime = r.start_time as string;
    const dt = new Date(`${dateStr}T${startTime}`);
    const dtIso = dt.toISOString();

    if (dtIso >= nowIso && dtIso <= in1hIso) {
      toNotify.push({
        user_id: r.user_id,
        title: "Reservation in 1 hour",
        message: `Your reservation at ${startTime} is in 1 hour.`,
      });
    } else if (dtIso > in1hIso && dtIso <= in24hIso) {
      toNotify.push({
        user_id: r.user_id,
        title: "Reservation in 24 hours",
        message: `You have a reservation tomorrow at ${startTime}.`,
      });
    }
  }

  if (toNotify.length > 0) {
    await supabaseClient.from("notifications").insert(toNotify);
  }

  return new Response(JSON.stringify({ count: toNotify.length }));
});

function createServiceClient() {
  const url = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // deno-lint-ignore no-explicit-any
  const { createClient }: any = (globalThis as any).supabase;

  return createClient(url, serviceKey);
}

