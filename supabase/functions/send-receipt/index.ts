import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  try {
    const { transaction_id, recipient, channel } = await req.json()
    console.log(`Sending receipt for transaction ${transaction_id} to ${recipient} via ${channel}`)

    return new Response(
      JSON.stringify({ success: true, message: "Receipt sent successfully" }),
      { headers: { "Content-Type": "application/json" } },
    )
  } catch (error: any) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    )
  }
})
