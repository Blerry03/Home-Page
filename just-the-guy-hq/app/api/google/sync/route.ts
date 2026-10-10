import { NextRequest,NextResponse } from 'next/server';
import {authenticate,decrypt,googleApi,googleReady,nextDate,tokenRequest} from '../../../../lib/google-server';
export const runtime='nodejs';
export async function POST(req:NextRequest){
 try{
  if(!googleReady)return NextResponse.json({error:'Google integration is not configured'},{status:503});
  const {db,user,orgId}=await authenticate(req);
  const {data:conn,error:ce}=await db.from('google_calendar_connections').select('refresh_token_ciphertext').eq('user_id',user.id).eq('organization_id',orgId).single();
  if(ce||!conn)throw new Error('Connect Google Calendar before syncing');
  const token=await tokenRequest(new URLSearchParams({grant_type:'refresh_token',refresh_token:decrypt(conn.refresh_token_ciphertext)}));
  const [{data:jobs,error:je},{data:clients,error:cl},{data:properties,error:pe},{data:maps,error:me}]=await Promise.all([
   db.from('jobs').select('id,client_id,property_id,title,scheduled_date,scheduled_start,scheduled_end,notes,status').eq('organization_id',orgId).not('scheduled_date','is',null).order('scheduled_date',{ascending:true}).limit(250),
   db.from('clients').select('id,name').eq('organization_id',orgId),
   db.from('properties').select('id,address_line1,city,state').eq('organization_id',orgId),
   db.from('google_calendar_events').select('job_id,google_event_id').eq('organization_id',orgId)
  ]);
  if(je||cl||pe||me)throw new Error([je,cl,pe,me].find(Boolean)?.message||'Database query failed');
  let synced=0,failed=0;const existing=new Map((maps||[]).map(m=>[m.job_id,m.google_event_id]));
  for(const job of jobs||[]){
   if(!job.scheduled_date)continue;
   const customer=clients?.find(c=>c.id===job.client_id)?.name||'Customer';
   const property=properties?.find(p=>p.id===job.property_id);
   const location=property?[property.address_line1,property.city,property.state].filter(Boolean).join(', '):'';
   const localDateTime=(d:string,t:string)=>d+'T'+t.slice(0,5)+':00';
   const startTime=job.scheduled_start as string|null;
   const endTime=job.scheduled_end as string|null;
   const fallbackEnd=()=>{const d=new Date(job.scheduled_date+'T'+startTime!.slice(0,5)+':00Z');d.setUTCHours(d.getUTCHours()+1);return d.toISOString().slice(0,19)};
   const eventStart=startTime?{dateTime:localDateTime(job.scheduled_date,startTime),timeZone:'America/Detroit'}:{date:job.scheduled_date};
   const eventEnd=startTime?{dateTime:endTime&&endTime>startTime?localDateTime(job.scheduled_date,endTime):fallbackEnd(),timeZone:'America/Detroit'}:{date:nextDate(job.scheduled_date)};
   const body={summary:`${customer} — ${job.title}`,location,description:`Just The Guy HQ job\nCustomer: ${customer}\nService: ${job.title}\nStatus: ${job.status}\n${job.notes||''}`,start:eventStart,end:eventEnd,extendedProperties:{private:{jtg_job_id:job.id}}};
   try{
    let id=existing.get(job.id);
    let res=id?await googleApi('calendars/primary/events/'+encodeURIComponent(id),token.access_token,'PATCH',body):await googleApi('calendars/primary/events',token.access_token,'POST',body);
    if(id&&res.status===404){id=undefined;res=await googleApi('calendars/primary/events',token.access_token,'POST',body);}
    if(!res.ok){failed++;continue;}
    const event=await res.json();
    const {error:writeError}=await db.from('google_calendar_events').upsert({organization_id:orgId,job_id:job.id,google_event_id:event.id,updated_at:new Date().toISOString()},{onConflict:'organization_id,job_id'});
    if(writeError){failed++;continue;}synced++;
   }catch{failed++;}
  }
  return NextResponse.json({synced,failed});
 }catch(e){return NextResponse.json({error:e instanceof Error?e.message:'Sync failed'},{status:400});}
}
