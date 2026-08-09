import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  try {
    const { campaign_id, salon_id } = await req.json()
    console.log(`Processing loyalty campaign ${campaign_id} for salon ${salon_id}`)

    return new Response(
      JSON.stringify({ success: true, sent_count: 1 }),
      { headers: { "Content-Type": "application/json" } },
    )
  } catch (error: any) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    )
  }
})
