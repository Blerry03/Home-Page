import {NextRequest,NextResponse} from 'next/server';
import {authenticate,createDocumentShareToken,decrypt,googleReady,tokenRequest} from '../../../../lib/google-server';
import {billingLineTotals} from '../../../../lib/billing-money';

export const runtime='nodejs';
const BUSINESS_EMAIL='justtheguyguttersandexterior@gmail.com';
const h=(value:unknown)=>String(value??'').replace(/[&<>\"']/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;',"'":'&#39;'}[char]!));
const money=(value:number)=>new Intl.NumberFormat('en-US',{style:'currency',currency:'USD'}).format(value);
const base64=(value:string)=>Buffer.from(value,'utf8').toString('base64').replace(/.{1,76}/g,'$&\r\n').trim();

function emailMarkup(input:{name:string;kind:string;number:string;title:string;total:number;balance:number;due:string;notes:string;viewUrl:string;logoUrl:string}){
 const isInvoice=input.kind==='invoice';
 const label=isInvoice?'invoice':'estimate';
 const greeting=input.name?`Dear ${h(input.name)},`:'Hello,';
 const opening=isInvoice
  ?`Please review the attached invoice for ${h(input.title)}. You can open a copy using the button below.`
  :`Thank you for contacting us. Please review the attached estimate for ${h(input.title)} at your convenience.`;
 const detail=isInvoice?`<tr><td style="padding:7px 0;color:#667085">Balance due</td><td style="padding:7px 0;text-align:right;font-weight:700;color:#0b2b65">${money(input.balance)}</td></tr>`:'';
 const due=input.due?`<tr><td style="padding:7px 0;color:#667085">${isInvoice?'Due date':'Expiration date'}</td><td style="padding:7px 0;text-align:right;color:#28364b">${h(input.due)}</td></tr>`:'';
 const notes=input.notes?`<p style="margin:20px 0 0;color:#4b5563;font-size:14px;line-height:1.6"><strong style="color:#27364b">Notes:</strong> ${h(input.notes)}</p>`:'';
 const cta=`VIEW ${isInvoice?'INVOICE':'ESTIMATE'}`;
 const html=`<!doctype html><html><body style="margin:0;background:#f3f4f6;padding:24px 12px;font-family:Arial,Helvetica,sans-serif;color:#27364b"><div style="max-width:600px;margin:0 auto"><div style="text-align:center;padding:10px 0 22px"><img src="${h(input.logoUrl)}" alt="Just The Guy Gutters &amp; Exteriors" width="190" style="width:190px;max-width:72%;height:auto;border:0;display:inline-block"></div><div style="background:#fff;border:1px solid #e5e7eb;border-radius:4px;padding:34px 32px 40px"><p style="margin:0 0 22px;font-size:15px;line-height:1.55">${greeting}</p><p style="margin:0 0 24px;font-size:15px;line-height:1.65">${opening}</p><p style="margin:0 0 24px;font-size:15px;line-height:1.65">Looking forward to doing business with you,<br>Just The Guy Gutters and Exteriors.</p><div style="text-align:center;margin:28px 0 34px;font-size:18px;color:#26364d"><span style="font-weight:700;color:#0b2b65">${isInvoice?'Invoice':'Estimate'}</span> #${h(input.number)}</div><div style="margin-top:12px"><h2 style="font-size:14px;margin:0 0 8px;color:#27364b">More details</h2><table role="presentation" style="width:100%;border-collapse:collapse;font-size:14px"><tr><td style="padding:7px 0;color:#667085">Total</td><td style="padding:7px 0;text-align:right;color:#28364b">${money(input.total)}</td></tr>${detail}${due}</table>${notes}</div><div style="margin:34px 0 16px;text-align:center"><a href="${h(input.viewUrl)}" style="display:inline-block;background:#08265f;color:#fff;text-decoration:none;font-weight:700;font-size:14px;letter-spacing:.3px;border-radius:5px;padding:15px 32px;min-width:220px">${cta}</a></div><p style="margin:18px 0 0;text-align:center;color:#7b8492;font-size:12px;line-height:1.5">A PDF copy is attached to this email.</p></div><p style="margin:18px 0 0;text-align:center;color:#7b8492;font-size:12px">Just The Guy Gutters &amp; Exteriors</p></div></body></html>`;
 const text=[greeting,'',opening,'','Looking forward to doing business with you,','Just The Guy Gutters and Exteriors.','',`${isInvoice?'Invoice':'Estimate'} #${input.number}`,`Total: ${money(input.total)}`,...(isInvoice?[`Balance due: ${money(input.balance)}`]:[]),...(input.due?[`${isInvoice?'Due date':'Expiration date'}: ${input.due}`]:[]),...(input.notes?[`Notes: ${input.notes}`]:[]),'',`View ${label}: ${input.viewUrl}`,'','A PDF copy is attached to this email.'].join('\n');
 return {html,text};
}

export async function POST(req:NextRequest){
 try{
  if(!googleReady)return NextResponse.json({error:'Google sending is not configured on this HQ deployment.'},{status:503});
  const {db,user,orgId}=await authenticate(req);
  const input=await req.json().catch(()=>null);
  const id=typeof input?.documentId==='string'?input.documentId:'';
  if(!/^[\da-f]{8}(?:-[\da-f]{4}){3}-[\da-f]{12}$/i.test(id))return NextResponse.json({error:'Choose a valid estimate or invoice.'},{status:400});
  const {data:doc,error:docError}=await db.from('documents').select('*').eq('id',id).eq('organization_id',orgId).single();
  if(docError||!doc)return NextResponse.json({error:'This document is not available in your HQ account.'},{status:404});
  if(doc.status==='void')return NextResponse.json({error:'A void document cannot be emailed.'},{status:409});
  if(typeof doc.recipient_email!=='string'||! /^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$/.test(doc.recipient_email.trim()))return NextResponse.json({error:'Add a valid recipient email to this document before sending.'},{status:400});
  const {data:connection,error:connectionError}=await db.from('google_calendar_connections').select('refresh_token_ciphertext').eq('user_id',user.id).maybeSingle();
  if(connectionError||!connection?.refresh_token_ciphertext)return NextResponse.json({error:'Connect the business Google account in HQ before sending.'},{status:409});

  const access=await tokenRequest(new URLSearchParams({grant_type:'refresh_token',refresh_token:decrypt(connection.refresh_token_ciphertext)}));
  const profile=await fetch('https://openidconnect.googleapis.com/v1/userinfo',{headers:{Authorization:'Bearer '+access.access_token},cache:'no-store'});
  const identity=await profile.json().catch(()=>({}));
  if(!profile.ok||typeof identity.email!=='string')return NextResponse.json({error:'Google sending access needs to be reconnected. In HQ, reconnect Google and approve Gmail sending.'},{status:409});
  const sender=identity.email.toLowerCase();
  if(sender!==BUSINESS_EMAIL)return NextResponse.json({error:`HQ is connected to ${identity.email}. Reconnect using ${BUSINESS_EMAIL} so emails come from the business account.`},{status:409});

  const bearer=req.headers.get('authorization');
  if(!bearer)return NextResponse.json({error:'Sign in again before sending.'},{status:401});
  const pdfUrl=new URL('/api/billing/document?id='+encodeURIComponent(doc.id),process.env.APP_BASE_URL).toString();
  const pdfResponse=await fetch(pdfUrl,{headers:{Authorization:bearer},cache:'no-store'});
  if(!pdfResponse.ok)return NextResponse.json({error:'Could not prepare the PDF attachment. Try again.'},{status:502});
  const pdfBytes=Buffer.from(await pdfResponse.arrayBuffer());
  if(!pdfBytes.length||pdfBytes.length>15*1024*1024)return NextResponse.json({error:'The PDF could not be attached because it is empty or too large.'},{status:422});

  const [clientResult,propertyResult,itemsResult,paymentsResult]=await Promise.all([
   db.from('clients').select('name').eq('id',doc.client_id).eq('organization_id',orgId).maybeSingle(),
   doc.property_id?db.from('properties').select('address_line1,city,state,postal_code').eq('id',doc.property_id).eq('organization_id',orgId).maybeSingle():Promise.resolve({data:null,error:null}),
   db.from('document_items').select('*').eq('document_id',id).eq('organization_id',orgId),
   db.from('document_payments').select('amount').eq('document_id',id).eq('organization_id',orgId),
  ]);
  if(clientResult.error||propertyResult.error||itemsResult.error||paymentsResult.error)return NextResponse.json({error:'Could not load all document details. Try again.'},{status:500});
  const items=itemsResult.data||[];
  const total=items.length?items.reduce((sum,item)=>sum+billingLineTotals(item).total,0):Number(doc.amount||0);
  const paid=(paymentsResult.data||[]).reduce((sum,payment)=>sum+Number(payment.amount),0);
  const balance=Math.max(0,total-paid);
  const name=clientResult.data?.name||'';
  const label=doc.kind==='invoice'?'Invoice':'Estimate';
  const share=createDocumentShareToken(doc.id);
  const shareUrl=new URL('/api/billing/document?id='+encodeURIComponent(doc.id)+'&share='+encodeURIComponent(share),process.env.APP_BASE_URL).toString();
  const noteParts=[doc.notes,propertyResult.data?[propertyResult.data.address_line1,[propertyResult.data.city,propertyResult.data.state,propertyResult.data.postal_code].filter(Boolean).join(' ')].filter(Boolean).join(', '):''].filter(Boolean);
  const logoUrl=new URL('/jtg-email-logo.png',process.env.APP_BASE_URL).toString();
  const {html,text}=emailMarkup({name,kind:doc.kind,number:doc.number,title:doc.title,total,balance,due:doc.due_date||doc.expiration_date||'',notes:noteParts.join(' · '),viewUrl:shareUrl,logoUrl});
  const subject=`${label} ${doc.number} | Just The Guy Gutters & Exteriors`;
  const mixed='jtg-mixed-'+crypto.randomUUID();const alternative='jtg-alt-'+crypto.randomUUID();
  const filename=`${label}-${String(doc.number).replace(/[^\w.-]+/g,'-')}.pdf`;
  const mime=[
   `From: Just The Guy Gutters & Exteriors <${sender}>`,`To: <${doc.recipient_email.trim()}>`,`Reply-To: ${sender}`,`Subject: =?UTF-8?B?${Buffer.from(subject,'utf8').toString('base64')}?=`,`MIME-Version: 1.0`,`Content-Type: multipart/mixed; boundary="${mixed}"`,'',
   `--${mixed}`,`Content-Type: multipart/alternative; boundary="${alternative}"`,'',
   `--${alternative}`,'Content-Type: text/plain; charset="UTF-8"','Content-Transfer-Encoding: base64','',base64(text),
   `--${alternative}`,'Content-Type: text/html; charset="UTF-8"','Content-Transfer-Encoding: base64','',base64(html),
   `--${alternative}--`,`--${mixed}`,'Content-Type: application/pdf; name="'+filename+'"','Content-Transfer-Encoding: base64','Content-Disposition: attachment; filename="'+filename+'"','',pdfBytes.toString('base64').match(/.{1,76}/g)?.join('\r\n')||'',`--${mixed}--`,'',
  ].join('\r\n');
  const sent=await fetch('https://gmail.googleapis.com/gmail/v1/users/me/messages/send',{method:'POST',headers:{Authorization:'Bearer '+access.access_token,'Content-Type':'application/json'},body:JSON.stringify({raw:Buffer.from(mime,'utf8').toString('base64url')}),cache:'no-store'});
  const sentData=await sent.json().catch(()=>({}));
  if(!sent.ok){
   const message=sent.status===401||sent.status===403?'Gmail sending access is not active yet. Reconnect Google in HQ and approve Gmail sending.':`Gmail could not send this email (${sent.status}). Try reconnecting Google and sending again.`;
   return NextResponse.json({error:message},{status:sent.status===401||sent.status===403?409:502});
  }
  let statusSaved=true;
  if(doc.status==='draft'){
   const {error:statusError}=await db.from('documents').update({status:'sent'}).eq('id',doc.id).eq('organization_id',orgId).eq('status','draft');
   statusSaved=!statusError;
  }
  return NextResponse.json({sent:true,recipient:doc.recipient_email.trim(),documentStatusSaved:statusSaved,messageId:sentData.id||null});
 }catch(error){
  const message=error instanceof Error?error.message:'Unable to send this document.';
  return NextResponse.json({error:message},{status:400});
 }
}
