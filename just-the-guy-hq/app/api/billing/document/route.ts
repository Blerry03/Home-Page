import {createClient} from '@supabase/supabase-js';
import {PDFDocument,StandardFonts,rgb} from 'pdf-lib';
import {billingLineTotals} from '../../../../lib/billing-money';

const money=(n:number)=>new Intl.NumberFormat('en-US',{style:'currency',currency:'USD'}).format(n);
const clean=(v:unknown)=>String(v??'').replace(/[‘’]/g,"'").replace(/[“”]/g,'"').replace(/[–—]/g,'-').replace(/[^\x20-\x7e\n]/g,'?');
const uuid=/^[\da-f]{8}(?:-[\da-f]{4}){3}-[\da-f]{12}$/i;

async function readDocument(request:Request){
 const id=new URL(request.url).searchParams.get('id')||'';
 const token=request.headers.get('authorization')?.match(/^Bearer (\S+)$/i)?.[1];
 if(!token||!uuid.test(id))return null;
 const url=process.env.NEXT_PUBLIC_SUPABASE_URL;
 const key=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
 if(!url||!key)return null;
 const db=createClient(url,key,{global:{headers:{Authorization:'Bearer '+token}},auth:{persistSession:false,autoRefreshToken:false}});
 const {data:doc,error}=await db.from('documents').select('*').eq('id',id).maybeSingle();
 if(error||!doc)return null;
 const [items,payments,client,property]=await Promise.all([
  db.from('document_items').select('*').eq('document_id',id).eq('organization_id',doc.organization_id).order('created_at').order('id'),
  db.from('document_payments').select('amount').eq('document_id',id).eq('organization_id',doc.organization_id),
  db.from('clients').select('name').eq('id',doc.client_id).eq('organization_id',doc.organization_id).single(),
  doc.property_id?db.from('properties').select('address_line1,city,state,postal_code').eq('id',doc.property_id).eq('organization_id',doc.organization_id).single():null,
 ]);
 if(items.error||payments.error||client.error||property?.error)throw new Error('Unable to load the complete document.');
 return {doc,items:items.data||[],payments:payments.data||[],client:client.data,property:property?.data};
}

async function makePdf(data:NonNullable<Awaited<ReturnType<typeof readDocument>>>){
 const {doc,items,payments,client,property}=data;
 const out=await PDFDocument.create();
 const regular=await out.embedFont(StandardFonts.Helvetica);
 const bold=await out.embedFont(StandardFonts.HelveticaBold);
 const blue=rgb(0.10,0.28,0.48);
 let page=out.addPage([612,792]),y=738;
 const label=doc.kind==='invoice'?'Invoice':'Estimate';
 out.setTitle(label+' '+clean(doc.number));
 function text(value:unknown,size=11,weight=false){
  const font=weight?bold:regular;
  for(const paragraph of clean(value).split('\n')){
   let line='';
   for(const char of paragraph){
    if(font.widthOfTextAtSize(line+char,size)>512){write(line);line='';}
    line+=char;
   }
   write(line);
  }
  function write(line:string){
   if(y<58){page=out.addPage([612,792]);y=738;}
   page.drawText(line,{x:50,y,size,font,color:blue});
   y-=size+5;
  }
 }
 text('Just The Guy Gutters & Exteriors',19,true);
 text(label+' '+doc.number,16,true);
 if(doc.issue_date)text('Issued '+doc.issue_date);
 if(doc.due_date)text((doc.kind==='invoice'?'Due ':'Expires ')+doc.due_date);
 y-=12;
 text(client?.name,12,true);
 if(property)text([property.address_line1,property.city,property.state,property.postal_code].filter(Boolean).join(', '));
 if(doc.purchase_order)text('Purchase order: '+doc.purchase_order);
 y-=12;text(doc.title,14,true);
 const sum={subtotal:0,discount:0,tax:0,total:0};
 for(const item of items){
  const v=billingLineTotals(item);
  text(item.item_name||item.description,11,true);
  if(item.item_name&&item.description)text(item.description);
  text(item.quantity+' '+item.unit+' at '+money(item.unit_price)+' = '+money(v.total));
  sum.subtotal+=v.base;sum.discount+=v.discount;sum.tax+=v.tax;sum.total+=v.total;
 }
 if(!items.length){sum.subtotal=Number(doc.amount);sum.total=sum.subtotal;}
 y-=12;
 text('Subtotal: '+money(sum.subtotal));
 if(sum.discount)text('Discount: '+money(sum.discount));
 if(sum.tax)text('Tax: '+money(sum.tax));
 text('Total: '+money(sum.total),14,true);
 const paid=payments.reduce((total,payment)=>total+Number(payment.amount),0);
 if(doc.kind==='invoice'&&paid){text('Payments received: '+money(paid));text('Balance due: '+money(sum.total-paid),12,true);}
 if(doc.contract_terms){y-=10;text('Terms',12,true);text(doc.contract_terms);}
 return {bytes:Buffer.from(await out.save()),filename:label+'-'+clean(doc.number).replace(/[^\w.-]+/g,'-')+'.pdf',label};
}

export async function GET(request:Request){
 try{
  const data=await readDocument(request);
  if(!data)return Response.json({error:'Document not available.'},{status:404});
  const pdf=await makePdf(data);
  return new Response(new Uint8Array(pdf.bytes),{headers:{'Content-Type':'application/pdf','Content-Disposition':'attachment; filename="'+pdf.filename+'"','Cache-Control':'private, no-store'}});
 }catch{return Response.json({error:'Unable to create the PDF.'},{status:500});}
}

