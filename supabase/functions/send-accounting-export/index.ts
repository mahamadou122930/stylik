import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  try {
    const { salon_id, from, to, format } = await req.json()
    console.log(`Generating accounting export (${format}) for salon ${salon_id} from ${from} to ${to}`)

    return new Response(
      JSON.stringify({ success: true, message: `Export (${format}) generated successfully` }),
      { headers: { "Content-Type": "application/json" } },
    )
  } catch (error: any) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    )
  }
})
