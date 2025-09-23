// ------------------------- IMPORTS -------------------------
const express = require('express');
const mongoose = require('mongoose');
const multer = require('multer');
const cors = require('cors');
const path = require('path');

// ------------------------- APP SETUP -------------------------
const app = express();
app.use(cors());
app.use(express.json());

// ------------------------- FILE UPLOAD SETUP -------------------------
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, 'uploads/'),
  filename: (req, file, cb) => cb(null, Date.now() + '-' + file.originalname)
});
const upload = multer({ storage });

// Make uploads folder accessible
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// ------------------------- MONGODB CONNECTION -------------------------
const mongoURI = "mongodb+srv://OCR_db_user:gydHqQV3TozuaQc8@cluster0.ubvfklc.mongodb.net/docsDB?retryWrites=true&w=majority"; // <- replace if needed

mongoose.connect(mongoURI, {
  useNewUrlParser: true,
  useUnifiedTopology: true
})
.then(() => console.log("MongoDB connected successfully"))
.catch(err => console.log("MongoDB connection error:", err));

// ------------------------- SCHEMA -------------------------
const documentSchema = new mongoose.Schema({
  title: String,
  date: { type: Date, default: Date.now },
  ocrText: String,
  fileUrl: String
});

const Document = mongoose.model('Document', documentSchema);

// ------------------------- ROUTES -------------------------

// Upload a document
app.post('/upload', upload.single('file'), async (req, res) => {
  try {
    const { title, ocrText } = req.body;
    const fileUrl = req.file ? `/uploads/${req.file.filename}` : null;

    const doc = new Document({ title, ocrText, fileUrl });
    await doc.save();

    res.json({ success: true, document: doc });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Get all documents
app.get('/documents', async (req, res) => {
  try {
    const docs = await Document.find().sort({ date: -1 });
    res.json(docs);
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Get single document by ID
app.get('/documents/:id', async (req, res) => {
  try {
    const doc = await Document.findById(req.params.id);
    if (!doc) return res.status(404).json({ success: false, message: "Document not found" });
    res.json(doc);
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ------------------------- START SERVER -------------------------
const PORT = 3000;
app.listen(PORT, () => console.log(`Server running on http://localhost:${PORT}`));
