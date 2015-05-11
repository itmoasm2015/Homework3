import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.PrintWriter;
import java.math.BigInteger;
import java.util.Random;
import java.util.Scanner;

/**
 * Created by evgeny on 09.05.15.
 */
public class GenBig {
    public static void main(String[] args) throws IOException {
        boolean ok = true;
        boolean check = false;
        while (ok) {
	        BigInteger ans = BigInteger.ZERO;
	        Scanner inn = null;
	        if (check)
	        	inn = new Scanner(new File("test.in"));
	        PrintWriter out = null; 
	        if (!check)
	        	out = new PrintWriter(new File("test.in"));
	        Random rnd = new Random();
	        int n = 100;
	        int m = 100;
	        if (check)
	        	n = inn.nextInt();
	        if (out != null)
	        	out.println(n);
	        for (int i = 0; i < n; i++) {
	            int k = rnd.nextInt(m);
	            int operation1 = rnd.nextInt(3);
	            out.println(k + " " + operation1);
	            BigInteger cur = BigInteger.ZERO;
	            while (k --> 0) {
		            long x = rnd.nextLong() % 1000000000000000L;
		            int operation = rnd.nextInt(3);
		            if (!check)
		            	out.println(operation + " " + x);
		            else {
		            	operation = inn.nextInt();
		            	x = inn.nextLong();
		            }
		            switch (operation) {
		                case 0:
		                    cur = cur.add(BigInteger.valueOf(x));
		                    break;
		                case 1:
		                    cur = cur.subtract(BigInteger.valueOf(x));
		                    break;
		                case 2:
		                    cur = cur.multiply(BigInteger.valueOf(x));
		                    break;
		            }
	          	}
	          	 switch (operation1) {
		           		case 0:
		           			ans = ans.add(cur);
		                break;
		             	case 1:
		                ans = ans.subtract(cur);
		                break;
		              case 2:
		                ans = ans.multiply(cur);
		                break;
		            }
	          	
	        }
	        if (out != null)
	        	out.close();
	        //if (true)return ;
	        try {
	        	Runtime.getRuntime().exec("./test").waitFor();
	      	} catch (Exception e) {}
	        Scanner in = new Scanner(new File("test.out"));
	        BigInteger mans = new BigInteger(in.next());
					System.out.println(ans.equals(mans)); 
        	System.out.println("True: " + ans + "\n" + "My:   " + mans); 
        	ok = ans.equals(mans);
        	if (check)
        		break;
	       }
    }
}