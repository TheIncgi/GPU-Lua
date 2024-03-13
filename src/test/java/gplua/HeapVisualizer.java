package gplua;

import java.awt.Color;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.IOException;

import javax.imageio.ImageIO;

import gplua.cl.TestBase;

public class HeapVisualizer {
	
	int tileSizeX = 4;
	int tileSizeY = 20;
	int tickScale = 8;
	private BufferedImage image;
	private int events;
	private int heapRecordIndex;
	final int MARGIN_X = tileSizeX * 12;
	final int MARGIN_Y = tileSizeY * 2;
	
	/**
	 * Index of allocations and de-allocations<br>
	 * Format
	 * Allocate:   [address][size]
	 * Deallocate: [addres][0]
	 * @throws IOException 
	 * */
	public HeapVisualizer(byte[] heap, int heapRecordIndex) throws IOException {
		var array = TestBase.getChunkData(heap, heapRecordIndex);
		this.events = array.arraySize() / 2;
		this.heapRecordIndex = heapRecordIndex;
		var usage = new int[heapRecordIndex];
		
		image = new BufferedImage(
			MARGIN_X + tileSizeX * (heapRecordIndex + 1), 
			MARGIN_Y + tileSizeY * (events + 1),
			BufferedImage.TYPE_INT_RGB);
		
		for(int i = 0; i < events; i++) {
			int index = array.arrayRef(i * 2);
			int size = array.arrayRef(i * 2 + 1);
			
			if( size == 0 ) {
				for( int j = index; usage[j] == index; j++ )
					usage[j] = 0;
			} else {
				for( int j = index; j < index + size; j++) {
					usage[j] = index;
				}				
			}
			drawEvent(i, usage);
		}
		
		drawFrameAndLabels();
	}
	
	public void save() throws IOException {
		ImageIO.write(image, "png", new File("debug.png"));
	}
	
	public void show() {
		BufferedImageViewer.show(image);
	}

	private void drawFrameAndLabels() {
		int tableStartX = MARGIN_X;
		int tableStartY = MARGIN_Y;
		int tableWidth = heapRecordIndex * tileSizeX;
		int tableHeight = events * tileSizeY;
		
		int mark = tickScale;    // % 10
		int halfMark = tickScale / 2; // %  5
		int quarterMark = tickScale / 4; // % 1
		
		var g = image.createGraphics();
		g.setColor(Color.white);
		
		for(int e = 0; e <= events; e++) {
			int xStart = tableStartX;
			var y = tableStartY + e * tileSizeY;
			if( e % 10 == 0) {
				g.setColor(Color.white);
				var fm = g.getFontMetrics();
				var sWid = fm.stringWidth(e+"");
				xStart -= mark;
				g.drawString(e+"", xStart - sWid-2, y + fm.getAscent()/2);
			} else if( e % 5 == 0) {
				g.setColor(Color.lightGray);
				xStart -= halfMark;
			} else {
				g.setColor(Color.darkGray);
				xStart -= quarterMark;
			}
			g.drawLine(xStart, y, tableStartX + tableWidth, y);
		}
		
		for(int h = 0; h <= heapRecordIndex; h++) {
			var x = tableStartX + h * tileSizeX;
			int yStart = tableStartY;
			if( h % 10 == 0) {
				g.setColor(Color.white);
				yStart -= mark;
				var fm = g.getFontMetrics();
				g.drawString(h+"", x, yStart - 2 );
			} else if( h % 5 == 0) {
				g.setColor(Color.lightGray);
				yStart -= halfMark;
			} else {
				g.setColor(Color.darkGray);
				yStart -= quarterMark;
			}
			g.drawLine(x, yStart, x, tableStartY + tableHeight);
		}
		
		g.setColor(Color.darkGray);
		
	}
	
	private void drawEvent(int i, int[] usage) {
		var g = image.createGraphics();
		int y = MARGIN_Y + i * tileSizeY;
		for(int offset = 0; offset < usage.length; offset++) {
			if( usage[offset] == 0 && offset >= 5 ) continue;
			int x = MARGIN_X + offset * tileSizeX;
			if( offset < 5 )
				g.setColor(Color.gray);
			else {
				var color = Color.getHSBColor((float) (usage[offset] * 100 * Math.PI), (float) (.7f - .2*( usage[offset] * 71321591 % 91 / 91f )), .8f);
				g.setColor(color);
			}
			g.fillRect(x, y, tileSizeX, tileSizeY);
		}
	}
	
}
