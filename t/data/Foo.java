import java.io.IOException;

public class Foo implements Comparable, Runnable {
    int bar;
    
    @Deprecated
    public static Thread quax;
    
    public void run() {        
    }
    
    public int compareTo(Object that) {
        return 0;
    }
    
    public static void main(String[] args) throws IOException {
        System.out.println("Hello World");
    }
}