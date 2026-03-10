import "jsr:@supabase/functions-js/edge-runtime.d.ts";

type Payload = {
  court_id: string;
  date: string;
  start_time: string;
  end_time: string;
  event_type: string;
  players_count: number;
};

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const supabaseClient = createClientFromReq(req);
  const authUser = await getAuthUser(supabaseClient);

  if (!authUser) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
    });
  }

  const body: Payload = await req.json();

  const { court_id, date, start_time, end_time, event_type, players_count } =
    body;

  const { data: okOverlap, error: overlapError } = await supabaseClient.rpc(
    "check_reservation_overlap",
    {
      p_court_id: court_id,
      p_date: date,
      p_start: start_time,
      p_end: end_time,
    },
  );

  if (overlapError) {
    return new Response(JSON.stringify({ error: overlapError.message }), {
      status: 400,
    });
  }

  if (!okOverlap) {
    return new Response(
      JSON.stringify({ error: "Time slot already booked" }),
      { status: 409 },
    );
  }

  const { data: price, error: priceError } = await supabaseClient.rpc(
    "calculate_booking_price",
    {
      p_date: date,
      p_start: start_time,
      p_end: end_time,
    },
  );

  if (priceError) {
    return new Response(JSON.stringify({ error: priceError.message }), {
      status: 400,
    });
  }

  const { data: reservation, error: insertError } = await supabaseClient
    .from("reservations")
    .insert({
      user_id: authUser.id,
      court_id,
      date,
      start_time,
      end_time,
      event_type,
      players_count,
      price,
      status: "PENDING",
    })
    .select("*")
    .single();

  if (insertError) {
    return new Response(JSON.stringify({ error: insertError.message }), {
      status: 400,
    });
  }

  await supabaseClient.from("notifications").insert({
    user_id: authUser.id,
    title: "Reservation created",
    message: "Your reservation is pending approval.",
  });

  return new Response(JSON.stringify({ reservation }), {
    headers: { "Content-Type": "application/json" },
  });
});

function createClientFromReq(req: Request) {
  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const authHeader = req.headers.get("Authorization");
  const jwt = authHeader?.replace("Bearer ", "");

  // deno-lint-ignore no-explicit-any
  const { createClient }: any = (globalThis as any).supabase;

  return createClient(url, anonKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
  });
}

async function getAuthUser(client: any) {
  const { data } = await client.auth.getUser();
  return data.user ?? null;
}

