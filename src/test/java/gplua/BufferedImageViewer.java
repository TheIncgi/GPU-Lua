package gplua;

import javax.swing.*;
import java.awt.*;
import java.awt.event.*;
import java.awt.image.BufferedImage;

//GPT
public class BufferedImageViewer extends JPanel implements MouseListener, MouseMotionListener, MouseWheelListener {
	private static final long serialVersionUID = 1L;
	private BufferedImage image;
    private int offsetX = 0;
    private int offsetY = 0;
    private double scale = 1.0;
    private int mouseX, mouseY;
    private boolean isDragging = false;

    public BufferedImageViewer(BufferedImage image) {
        this.image = image;
        setPreferredSize(new Dimension(image.getWidth(), image.getHeight()));
        addMouseListener(this);
        addMouseMotionListener(this);
        addMouseWheelListener(this);
    }

    @Override
    protected void paintComponent(Graphics g) {
        super.paintComponent(g);
        Graphics2D g2d = (Graphics2D) g;
        g2d.setBackground(Color.black);
        g2d.clearRect(0, 0, getWidth(), getHeight());

        if (scale < 1.2) {
            // Set rendering hints for better image quality when zoomed out
            g2d.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BICUBIC);
            g2d.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
        } else {
            // Set rendering hints for nearest-neighbor interpolation when zoomed in
            g2d.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_NEAREST_NEIGHBOR);
            g2d.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_SPEED);
        }

        int imageWidth = (int) (image.getWidth() * scale);
        int imageHeight = (int) (image.getHeight() * scale);
        int x =  offsetX;
        int y =  offsetY;
        g2d.drawImage(image, x, y, imageWidth, imageHeight, null);
    }

    @Override
    public void mousePressed(MouseEvent e) {
        mouseX = e.getX();
        mouseY = e.getY();
        isDragging = true;
    }

    @Override
    public void mouseReleased(MouseEvent e) {
        isDragging = false;
    }

    @Override
    public void mouseDragged(MouseEvent e) {
        if (isDragging) {
            int dx = e.getX() - mouseX;
            int dy = e.getY() - mouseY;
            mouseX = e.getX();
            mouseY = e.getY();
            offsetX += dx;
            offsetY += dy;
            repaint();
        }
    }

    public void mouseWheelMoved(MouseWheelEvent e) {
        double scaleFactor = 1.1;
        int mousePosX = e.getX();
        int mousePosY = e.getY();

        double prevScale = scale;
        if (e.getWheelRotation() < 0) {
            scale *= scaleFactor;
        } else {
            scale /= scaleFactor;
        }

        // Get mouse position in image coordinates
        int imageMouseX = (int) ((mousePosX - offsetX) / prevScale);
        int imageMouseY = (int) ((mousePosY - offsetY) / prevScale);

        // Adjust offsets to keep the image position under the mouse after zooming
        offsetX = (int) (mousePosX - imageMouseX * scale);
        offsetY = (int) (mousePosY - imageMouseY * scale);

        repaint();
    }

    @Override
    public void mouseClicked(MouseEvent e) {}

    @Override
    public void mouseEntered(MouseEvent e) {}

    @Override
    public void mouseExited(MouseEvent e) {}

    @Override
    public void mouseMoved(MouseEvent e) {}

    public static void show(BufferedImage image) {
        SwingUtilities.invokeLater(() -> {
            JFrame frame = new JFrame("Image Viewer");
            var imagePanel = new BufferedImageViewer(image);
//            frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
            frame.getContentPane().add(imagePanel);
            frame.pack();
            frame.setLocationRelativeTo(null);
            frame.getContentPane().setBackground(Color.BLACK);
            frame.setSize((int) Math.min(1200, image.getWidth() * 1.5), Math.min(900, image.getHeight() * 2));
            frame.setVisible(true);
        });
    }
}
