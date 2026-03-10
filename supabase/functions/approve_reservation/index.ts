import "jsr:@supabase/functions-js/edge-runtime.d.ts";

type Payload = {
  reservation_id: string;
  status: "APPROVED" | "REJECTED";
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

  const { data: me } = await supabaseClient
    .from("users")
    .select("role")
    .eq("id", authUser.id)
    .single();

  if (!me || me.role !== "admin") {
    return new Response(JSON.stringify({ error: "Forbidden" }), {
      status: 403,
    });
  }

  const body: Payload = await req.json();

  if (!["APPROVED", "REJECTED"].includes(body.status)) {
    return new Response(JSON.stringify({ error: "Invalid status" }), {
      status: 400,
    });
  }

  const { data: reservation, error } = await supabaseClient
    .from("reservations")
    .update({ status: body.status })
    .eq("id", body.reservation_id)
    .select("id,user_id,status")
    .single();

  if (error || !reservation) {
    return new Response(JSON.stringify({ error: "Reservation not found" }), {
      status: 404,
    });
  }

  const title =
    body.status === "APPROVED"
      ? "Reservation approved"
      : "Reservation rejected";
  const message =
    body.status === "APPROVED"
      ? "Your reservation has been approved."
      : "Your reservation has been rejected.";

  await supabaseClient.from("notifications").insert({
    user_id: reservation.user_id,
    title,
    message,
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

