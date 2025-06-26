import { LightningElement , api , wire} from 'lwc';
import getInvoiceDetails from '@salesforce/apex/invoicePrintAndDownload.getInvoiceDetails';
import html2canvasLib from '@salesforce/resourceUrl/html2canvas';
import jsPdfLib from '@salesforce/resourceUrl/jspdf';
import { loadScript } from 'lightning/platformResourceLoader';
export default class InvoicePrintableFormat extends LightningElement {
   @api recordId;
  invoice;
  scriptsLoaded = false;

  @wire(getInvoiceDetails, { invoiceId: '$recordId' })
  wiredInvoice({ error, data }) {
    if (data) {
      this.invoice = data;
    } else if (error) {
      console.error('Error loading invoice:', error);
    }
  }

  renderedCallback() {
    if (this.scriptsLoaded) return;
    this.scriptsLoaded = true;

    Promise.all([
      loadScript(this, html2canvasLib),
      loadScript(this, jsPdfLib)
    ]).catch((e) => {
      console.error('Library load error:', e);
    });
  }

  handlePrint() {
    window.print();
  }

  async handleDownloadPdf() {
    const container = this.refs.printArea;

    const canvas = await html2canvas(container);
    const imgData = canvas.toDataURL('image/png');
    const { jsPDF } = window.jspdf;
    const pdf = new jsPDF();

    const width = pdf.internal.pageSize.getWidth();
    const height = (canvas.height * width) / canvas.width;

    pdf.addImage(imgData, 'PNG', 0, 0, width, height);
    pdf.save('Invoice.pdf');
  }
}